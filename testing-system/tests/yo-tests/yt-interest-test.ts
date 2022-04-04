import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { assert } from 'console';
import { BigNumber as BN, Wallet } from 'ethers';
import { ERC20, ERC20__factory, PendleYieldToken } from '../../../typechain-types';
import { buildEnv, TestEnv } from '../../environment';
import { parseLYTSingleEnv } from '../../environment/fixtures';
import { BenqiLyt } from '../../environment/fixtures/avalanche/deployBenqi';
import { BenqiYTLYT } from '../../environment/fixtures/avalanche/deployYieldToken';
import {
  advanceTime,
  approxBigNumber,
  approxByPercent,
  clearFund,
  errMsg,
  evm_revert,
  evm_snapshot,
  fundToken,
  getLastBlockTimestamp,
  getSumBalance,
  minBN,
  minBNs,
  random,
  setTimeNextBlock,
} from '../../helpers';
import { runTest as runLYTRewardTest } from '../lyt-tests/reward-test';

describe('YT Reward tests', async () => {
  let env: TestEnv;
  let lyt: BenqiLyt;
  let yt: PendleYieldToken;
  let ytLyt: BenqiYTLYT;

  let globalSnapshotId: string;
  let snapshotId: string;
  let wallets: SignerWithAddress[];
  let REF_AMOUNT_WEI: BN;

  let underlying: ERC20;
  let yieldToken: ERC20;

  before(async () => {
    env = await buildEnv();
    globalSnapshotId = await evm_snapshot();
    snapshotId = await evm_snapshot();
    wallets = env.wallets;
    lyt = env.qiLyt;
    ytLyt = env.ytLyt;
  });

  beforeEach(async () => {
    await evm_revert(snapshotId);
    snapshotId = await evm_snapshot();
    await parseLYTSingleEnv(env, ytLyt);
    env = await parseLYTSingleEnv(env, lyt);
    ({ underlying, yieldToken, REF_AMOUNT_WEI, yt, ytLyt } = env);
    await clearFund(env, wallets, [underlying.address, yieldToken.address]);
  });

  after(async () => {
    await evm_revert(globalSnapshotId);
  });

  async function mintLyt(person: SignerWithAddress, amount: BN): Promise<void> {
    await fundToken(env, [person.address], underlying.address, amount);
    await lyt.mint(person, person.address, underlying.address, amount);
  }

  async function mintYO(person: SignerWithAddress, amount: BN): Promise<void> {
    await mintLyt(person, amount);
    await ytLyt.mintYieldToken(person, await lyt.balanceOf(person.address));
  }

  it('YT & OT Holders should receive the same amount of interest as lyt holders', async () => {
    async function convertLytToAsset(amount: BN): Promise<BN> {
      return amount.mul(await lyt.indexCurrent()).div(BN.from(10).pow(18));
    }

    async function checkBalance(totalFunded: BN) {
      let sumInterest = BN.from(0);
      let sumLytAsset = BN.from(0);

      for (let i = 0; i < 2; ++i) {
        // fake call to update interest
        await yt.connect(wallets[i]).transfer(env.mconsts.DUMMY_ADDRESS, 0);
        sumInterest = sumInterest.add(
          await convertLytToAsset((await yt.data(wallets[i].address))[1])
        );
      }

      for (let i = 2; i < 5; ++i) {
        sumLytAsset = sumLytAsset.add(
          await convertLytToAsset(await lyt.balanceOf(wallets[i].address))
        );
      }

      expect(sumInterest).to.be.gt(0);
      approxByPercent(sumInterest, sumLytAsset.sub(totalFunded));
    }

    const NUM_ITERS = 50;
    let totalFunded: BN = BN.from(0);
    for (let iter = 0; iter < NUM_ITERS; ++iter) {
      let i1 = random(0, 2);
      let i2 = random(2, 5);
      await mintYO(wallets[i1], REF_AMOUNT_WEI);
      await mintLyt(wallets[i2], REF_AMOUNT_WEI);
      totalFunded = totalFunded.add(REF_AMOUNT_WEI);
      await advanceTime(env.mconsts.ONE_DAY);
      await lyt.addFakeIncome(env);
      await checkBalance(totalFunded);
    }
  });

  it('OT holders should be able to redeem their underlying after expiry', async () => {
    async function checkDualBalance(i: number): Promise<void> {
      assert(i > 0);
      approxByPercent(
        (await underlying.balanceOf(wallets[i - 1].address)).mul(2),
        await underlying.balanceOf(wallets[i].address)
      );
    }

    for (let i = 0; i < wallets.length; ++i) {
      const person = wallets[i];
      const amount = REF_AMOUNT_WEI.mul(2 ** i);
      await fundToken(env, [person.address], underlying.address, amount);
      await lyt.mint(person, person.address, underlying.address, amount);
      await ytLyt.mintYieldToken(person, await lyt.balanceOf(person.address));
    }
    await setTimeNextBlock(env.expiry.add(env.startTime).div(2));

    for (let i = 0; i < wallets.length; ++i) {
      const person = wallets[i];
      const amount = await yt.balanceOf(person.address);
      await expect(
        env.fundKeeper.connect(person).redeemYOAfterExpiryPull(env.yt.address, amount)
      ).to.be.revertedWith(errMsg.FUNDKEEPER_NOT_EXPIRED);
    }

    await setTimeNextBlock(env.expiry.sub(env.mconsts.ONE_HOUR));
    await yt.redeemDueInterest(env.mconsts.DUMMY_ADDRESS); // update interest

    await setTimeNextBlock(env.expiry.add(1));
    for (let i = 0; i < wallets.length; ++i) {
      const person = wallets[i];
      const amount = await yt.balanceOf(person.address);
      await env.fundKeeper.connect(person).redeemYOAfterExpiryPull(yt.address, amount);
      await lyt.redeem(
        person,
        person.address,
        underlying.address,
        await lyt.balanceOf(person.address)
      );

      expect(await underlying.balanceOf(person.address)).to.be.gt(0);
      if (i > 1) await checkDualBalance(i);
    }

    for (let i = 0; i < wallets.length; ++i) {
      const person = wallets[i];

      const preBal = await underlying.balanceOf(person.address);
      await yt.redeemDueInterest(person.address);
      await lyt.redeem(
        person,
        person.address,
        underlying.address,
        await lyt.balanceOf(person.address)
      );
      const postBal = await underlying.balanceOf(person.address);

      expect(postBal).to.be.gt(preBal);
      if (i > 1) await checkDualBalance(i);
    }
  });
});
