import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber as BN } from 'ethers';
import { ERC20 } from '../../../typechain-types';
import { buildEnv, TestEnv } from '../../environment';
import { parseLYTSingleEnv } from '../../environment/fixtures';
import { BenqiLyt } from '../../environment/fixtures/avalanche/deployBenqi';
import { BenqiYTLYT } from '../../environment/fixtures/avalanche/deployYieldToken';
import {
  advanceTime,
  approxBigNumber,
  approxByPercent,
  clearFund,
  evm_revert,
  evm_snapshot,
  fundToken,
  getLastBlockTimestamp,
  minBN,
  minBNs,
  random,
  setTimeNextBlock,
} from '../../helpers';
import { runTest as runLYTRewardTest } from '../lyt-tests/reward-test';

describe('YT Reward tests', async () => {
  let env: TestEnv;
  let lyt: BenqiYTLYT;
  let qiLyt: BenqiLyt;

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
    lyt = env.ytLyt;
    qiLyt = env.qiLyt;
  });

  beforeEach(async () => {
    await evm_revert(snapshotId);
    snapshotId = await evm_snapshot();
    await parseLYTSingleEnv(env, qiLyt);
    env = await parseLYTSingleEnv(env, lyt);
    ({ underlying, yieldToken, REF_AMOUNT_WEI } = env);
    await clearFund(env, wallets, [underlying.address, yieldToken.address]);
  });

  after(async () => {
    await evm_revert(globalSnapshotId);
  });

  it('Run regular LYT reward test', async () => {
    await runLYTRewardTest(env, lyt);
  });

  async function getRewardBalances(peopleIds: number[], rwdId: number = 0): Promise<BN> {
    let res = BN.from(0);
    for (let id of peopleIds) {
      res = res.add(await lyt.rewardBalance(wallets[id].address, rwdId));
    }
    return res;
  }

  it('YT holder should receive the same amount of rewards as LYT holders and yieldtoken holder', async () => {
    const NUM_ITERS = 50;
    for (let i = 0; i < NUM_ITERS; ++i) {
      let p1 = wallets[random(0, 2)]; // holds yt
      let p2 = wallets[2 + random(0, 2)]; // holds lyt
      let p3 = wallets[4]; // holds qiUSD

      let action = random(0, 2);
      if (i == 0 || action == 0) {
        await fundToken(env, [p1.address, p2.address], lyt.underlying.address, REF_AMOUNT_WEI);
        await fundToken(env, [p3.address], qiLyt.underlying.address, REF_AMOUNT_WEI.mul(2));
        await qiLyt.mintYieldToken(p3, REF_AMOUNT_WEI);
        await lyt.mintYieldToken(p1, REF_AMOUNT_WEI);
      } else {
        let burnAmount = minBNs([
          await yieldToken.balanceOf(p1.address),
          await underlying.balanceOf(p2.address),
          await qiLyt.yieldToken.balanceOf(p3.address),
        ]);
        if (burnAmount.gt(0)) {
          burnAmount = burnAmount.div(2);
          await lyt.burnYieldToken(p1, burnAmount);
          await qiLyt.redeem(p2, p2.address, qiLyt.underlying.address, burnAmount);
          await qiLyt.burnYieldToken(p3, burnAmount);
        }
      }
      await advanceTime(env.mconsts.ONE_DAY);
    }

    for (let i = 0; i < 5; ++i) {
      let person = wallets[i];
      if (i < 2) await lyt.claimDirectReward(person, person.address);
      else if (i < 4) await qiLyt.redeemReward(person, person.address);
      else qiLyt.claimDirectReward(person, person.address);
    }

    approxByPercent(await getRewardBalances([0, 1]), await getRewardBalances([2, 3]), 10000);

    approxByPercent(await getRewardBalances([0, 1]), await getRewardBalances([4]), 10000);
  });

  it('YT should not receive reward after expiry', async () => {
    await fundToken(
      env,
      wallets.map((v) => v.address),
      underlying.address,
      REF_AMOUNT_WEI
    );
    await env.fundKeeper.redeemAllYO(env.yt.address);

    const [alice] = wallets;
    await lyt.mintYieldToken(alice, REF_AMOUNT_WEI);

    const FIVE_MONTH = env.mconsts.ONE_MONTH.mul(5);
    await setTimeNextBlock(FIVE_MONTH.add(env.startTime));
    await lyt.claimDirectReward(alice, alice.address);
    const fiveMonthRewards = await lyt.rewardBalance(alice.address);

    await setTimeNextBlock(env.expiry.sub(30));
    await lyt.claimDirectReward(alice, alice.address);
    const currentReward = await lyt.rewardBalance(alice.address);

    approxByPercent(
      currentReward.sub(fiveMonthRewards),
      fiveMonthRewards.div(5),
      10 // to be investigate, low precision
    );

    await setTimeNextBlock(env.expiry.add(FIVE_MONTH));
    await lyt.claimDirectReward(alice, alice.address);

    approxByPercent(await lyt.rewardBalance(alice.address), currentReward);

    await env.yt.withdrawFeeToTreasury();
    approxByPercent(await lyt.rewardBalance(env.treasury.address), fiveMonthRewards);
  });
});
