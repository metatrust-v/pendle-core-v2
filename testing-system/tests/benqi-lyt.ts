import {
  advanceTime,
  evm_revert,
  evm_snapshot,
  getEth,
  impersonateAccount,
  impersonateAccountStop,
  getBalance,
  approxBigNumber,
  random,
  errMsg,
  approveAll,
  clearFund,
  fundToken,
  getContractAt,
  transferNative,
} from '../helpers';
import { buildEnv, TestEnv } from '../environment';
import { BenqiLyt } from '../environment/fixtures/avalanche/deployBenqi';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber as BN } from 'ethers';
import hre, { ethers } from 'hardhat';
import { ERC20, IWETH, QiErc20 } from '../../typechain-types';
import { expect } from 'chai';
import { assert } from 'console';
import { Erc20Token } from '@pendle/constants';

describe('Benqi-lyt test', async () => {
  const [ALICE, LYT] = [0, 1];
  const LYT_DECIMAL = 18;
  const MINUTES_PER_DAY = 1440;
  const MINUTES_PER_MONTH = MINUTES_PER_DAY * 30;

  let globalSnapshotId: string;
  let snapshotId: string;
  let env: TestEnv;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let charlie: SignerWithAddress;

  let REF_AMOUNT: BN;
  let REF_AMOUNT_WEI: BN;

  let lyt: BenqiLyt;
  let underlying: ERC20;
  let yieldToken: QiErc20;
  let rewardTokens: string[];
  let lytRewardsTokens: string[];

  let allContracts: string[];

  /*///////////////////////////////////////////////////////////////
                            Setting up
    //////////////////////////////////////////////////////////////*/
  before(async () => {
    globalSnapshotId = await evm_snapshot();

    await prepTestEnv();
    await prepTestScenerio();

    snapshotId = await evm_snapshot();
  });

  beforeEach(async () => {
    await evm_revert(snapshotId);
    snapshotId = await evm_snapshot();
  });

  after(async () => {
    await evm_revert(globalSnapshotId);
  });

  async function prepTestEnv() {
    env = await buildEnv();
    [alice, bob, charlie] = await hre.ethers.getSigners();
    await getEth(bob.address);
    await getEth(charlie.address);

    REF_AMOUNT = BN.from(10 ** 2);
    REF_AMOUNT_WEI = REF_AMOUNT.mul(10 ** env.aconsts.tokens.USDC.decimal);

    lyt = env.qiLyt;
    underlying = lyt.underlying;
    yieldToken = lyt.qiToken;
    rewardTokens = [env.qiToken.address, env.aconsts.tokens.NATIVE.address];
    lytRewardsTokens = [env.qiToken.address, env.aconsts.tokens.WNATIVE.address];

    allContracts = [alice.address, lyt.lyt.address];
  }

  async function prepTestScenerio() {
    await approveAll(env, underlying.address, lyt.lyt.address);
    await approveAll(env, yieldToken.address, lyt.lyt.address);
    await fundToken(env, [alice.address], underlying.address, REF_AMOUNT_WEI.mul(2));
    await lyt.mintYieldToken(alice, REF_AMOUNT_WEI);
  }

  async function fakeReduceExchangeRate() {
    let signer = await hre.ethers.getSigner(yieldToken.address);
    const currentBal = await underlying.balanceOf(yieldToken.address);
    await getEth(yieldToken.address);
    await impersonateAccount(yieldToken.address);
    await underlying.connect(signer).transfer(env.fundKeeper.address, currentBal.div(10));
    await impersonateAccountStop(yieldToken.address);
  }

  async function getRewardAmount(person: SignerWithAddress, tokens: string[], getReward: any) {
    const preBals: BN[] = [];
    for (const token of tokens) {
      preBals.push((await getBalance(token, [person.address]))[0]);
    }

    await getReward();

    const posBals: BN[] = [];
    for (const token of tokens) {
      posBals.push((await getBalance(token, [person.address]))[0]);
    }

    const res: BN[] = [];
    for (let i = 0; i < preBals.length; ++i) {
      res.push(posBals[i].sub(preBals[i]));
    }
    return res;
  }

  /*///////////////////////////////////////////////////////////////
                    DEPOSIT USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

  it('Deposit base token success', async () => {
    const [expectedYield] = await getBalance(yieldToken, [alice.address]);

    const [preBal] = await getBalance(yieldToken, [lyt.lyt.address]);
    const amountLYTOut = await lyt.depositBaseToken(alice, underlying.address, REF_AMOUNT_WEI);
    const [posBal] = await getBalance(yieldToken, [lyt.lyt.address]);

    expect(expectedYield).to.be.gt(0);
    expect(await underlying.balanceOf(alice.address)).to.be.eq(0);
    expect(posBal.sub(preBal)).to.be.eq(amountLYTOut);
    expect(amountLYTOut).to.be.eq(await lyt.lyt.balanceOf(alice.address));

    // value of qiToken factor in times, so exchange rate could have increase slightly during depositBaseToken
    approxBigNumber(await lyt.lyt.balanceOf(alice.address), expectedYield, 10 ** env.aconsts.tokens.USDC.decimal);
  });

  it('Deposit base token for recipient', async () => {
    const [expectedYield] = await getBalance(yieldToken, [alice.address]);
    await lyt.depositBaseTokenFor(alice, charlie.address, underlying.address, REF_AMOUNT_WEI);

    expect((await getBalance(underlying, [alice.address]))[0]).to.be.eq(0);
    approxBigNumber(await lyt.balanceOf(charlie.address), expectedYield, 10 ** env.aconsts.tokens.USDC.decimal);
  });

  it('Deposit base token revert', async () => {
    const [expectedYield] = await getBalance(yieldToken, [alice.address]);

    await expect(lyt.depositBaseToken(alice, alice.address, REF_AMOUNT_WEI)).to.be.revertedWith(
      errMsg.INVALID_BASE_TOKEN
    );
    await expect(lyt.depositBaseToken(alice, underlying.address, REF_AMOUNT_WEI.add(1))).to.be.revertedWith(
      errMsg.ERC20_TRANSFER_EXCEEDS_BALANCE
    );
    await expect(
      lyt.depositBaseToken(alice, underlying.address, REF_AMOUNT_WEI, expectedYield.add(1))
    ).to.be.revertedWith(errMsg.INSUFFICIENT_OUT);
  });

  /*///////////////////////////////////////////////////////////////
                    REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/
  it('Redeem base token success', async () => {
    await lyt.depositBaseToken(alice, underlying.address, REF_AMOUNT_WEI);
    const [lytBal] = await getBalance(lyt.lyt, [alice.address]);
    const [preBal] = await getBalance(yieldToken, [lyt.lyt.address]);
    const amountBaseOut = await lyt.redeemBaseToken(alice, underlying.address, lytBal);
    const [posBal] = await getBalance(yieldToken, [lyt.lyt.address]);

    // math error from benqi mint then redeem:
    // base -> yield -> base conversion can make base decrease due to round down from division/multiplication
    approxBigNumber(amountBaseOut, REF_AMOUNT_WEI, 10 ** env.aconsts.tokens.USDC.decimal);
    expect(amountBaseOut).to.be.eq(await underlying.balanceOf(alice.address));
    expect(amountBaseOut).to.be.gt(0);
    expect(await lyt.lyt.balanceOf(alice.address)).to.be.eq(0);
    expect(preBal.sub(posBal)).to.be.eq(lytBal);
  });

  it('Redeem base token for recipient', async () => {
    const initialBal = await lyt.yieldTokenBalance(alice.address);
    await lyt.depositYieldToken(alice, initialBal);
    await lyt.redeemBaseTokenFor(alice, charlie.address, underlying.address, initialBal);

    expect(await lyt.balanceOf(alice.address)).to.be.eq(0);
    approxBigNumber(await underlying.balanceOf(charlie.address), REF_AMOUNT_WEI, 10 ** env.aconsts.tokens.USDC.decimal);
  });

  it('Redeem base token after deposit yield token', async () => {
    const amountLytOut = await lyt.depositYieldToken(alice, await lyt.yieldTokenBalance(alice.address));
    const amountBaseOut = await lyt.redeemBaseToken(alice, underlying.address, amountLytOut);

    approxBigNumber(amountBaseOut, REF_AMOUNT_WEI, 10 ** env.aconsts.tokens.USDC.decimal);
  });

  it('Redeem base token revert', async () => {
    await lyt.depositBaseToken(alice, underlying.address, REF_AMOUNT_WEI);
    const [lytBal] = await getBalance(lyt.lyt, [alice.address]);
    await expect(lyt.redeemBaseToken(alice, alice.address, lytBal)).to.be.revertedWith(errMsg.INVALID_BASE_TOKEN);
    await expect(lyt.redeemBaseToken(alice, underlying.address, lytBal.add(1))).to.be.revertedWith(
      errMsg.ERC20_BURN_EXCEEDS_BALANCE
    );
    await expect(lyt.redeemBaseToken(alice, underlying.address, lytBal, REF_AMOUNT_WEI.add(1))).to.be.revertedWith(
      errMsg.INSUFFICIENT_OUT
    );
  });

  /*///////////////////////////////////////////////////////////////
                DEPOSIT USING THE YIELD TOKEN
    //////////////////////////////////////////////////////////////*/
  it('Deposit yield token success', async () => {
    const preBal = await getBalance(yieldToken, allContracts);
    const amountLYTOut = await lyt.depositYieldToken(alice, preBal[ALICE]);
    const posBal = await getBalance(yieldToken, allContracts);
    const lytBal = await getBalance(lyt.lyt, allContracts);

    expect(preBal[ALICE]).to.be.gt(0);
    expect(posBal[ALICE]).to.be.eq(0);
    expect(preBal[ALICE]).to.be.eq(lytBal[ALICE]);
    expect(preBal[ALICE]).to.be.eq(posBal[LYT].sub(preBal[LYT]));
    expect(amountLYTOut).to.be.eq(preBal[ALICE]);
  });

  it('Deposit yield token for recipient', async () => {
    const initialBal = await lyt.yieldTokenBalance(alice.address);
    await lyt.depositYieldTokenFor(alice, charlie.address, initialBal);

    expect(await lyt.yieldTokenBalance(alice.address)).to.be.eq(0);
    expect(await lyt.balanceOf(charlie.address)).to.be.eq(initialBal);
  });

  it('Deposit yield token revert', async () => {
    const [preBal] = await getBalance(yieldToken, [alice.address]);

    await expect(lyt.depositYieldToken(alice, preBal.add(1))).to.be.revertedWith(errMsg.SAFE_ERC20_FAILED);
    await expect(lyt.depositYieldToken(alice, preBal, preBal.add(1))).to.be.revertedWith(errMsg.INSUFFICIENT_OUT);
  });

  /*///////////////////////////////////////////////////////////////
                REDEEM USING THE YIELD TOKEN
    //////////////////////////////////////////////////////////////*/

  it('Redeem yield token success', async () => {
    const preBal = await getBalance(yieldToken, allContracts);
    await lyt.depositYieldToken(alice, preBal[ALICE]);
    const amountYieldOut = await lyt.redeemYieldToken(alice, preBal[ALICE]);
    const posBal = await getBalance(yieldToken, allContracts);
    const lytBal = await getBalance(lyt.lyt, allContracts);

    expect(preBal[ALICE]).to.be.gt(0);
    expect(preBal[ALICE]).to.be.eq(posBal[ALICE]);
    expect(lytBal[ALICE]).to.be.eq(0);
    expect(posBal[LYT].sub(preBal[LYT])).to.be.eq(0);
    expect(amountYieldOut).to.be.eq(preBal[ALICE]);
  });

  it('Redeem yield token for recipient', async () => {
    const initialBal = await lyt.yieldTokenBalance(alice.address);
    await lyt.depositYieldToken(alice, initialBal);
    await lyt.redeemYieldTokenFor(alice, charlie.address, initialBal);

    expect(await lyt.balanceOf(alice.address)).to.be.eq(0);
    expect(await lyt.yieldTokenBalance(charlie.address)).to.be.eq(initialBal);
  });

  it('Redeem yield token after deposit base token', async () => {
    const amountLYTOut = await lyt.depositBaseToken(alice, underlying.address, REF_AMOUNT_WEI);
    const amountYieldOut = await lyt.redeemYieldToken(alice, amountLYTOut);

    expect(amountYieldOut).to.be.eq(amountLYTOut);
  });

  it('Redeem yield token revert', async () => {
    const [preBal] = await getBalance(yieldToken, [alice.address]);
    await lyt.depositYieldToken(alice, preBal);

    await expect(lyt.redeemYieldToken(alice, preBal.add(1))).to.be.revertedWith(errMsg.ERC20_BURN_EXCEEDS_BALANCE);
    await expect(lyt.redeemYieldToken(alice, preBal, preBal.add(1))).to.be.revertedWith(errMsg.INSUFFICIENT_OUT);
  });

  /*///////////////////////////////////////////////////////////////
                               LYT-INDEX
    //////////////////////////////////////////////////////////////*/

  it('Asset balance', async () => {
    const expectedResult = await yieldToken.callStatic.balanceOfUnderlying(alice.address);
    const [preBal] = await getBalance(yieldToken, [alice.address]);
    await lyt.depositYieldToken(alice, preBal);

    expect(await lyt.lyt.callStatic.assetBalanceOf(alice.address)).to.be.eq(expectedResult);
  });

  it('Lyt index current', async () => {
    const preIndex = await lyt.lyt.callStatic.lytIndexCurrent();
    await lyt.addFakeIncome(env);

    const posIndex = await lyt.lyt.callStatic.lytIndexCurrent();

    expect(posIndex).to.be.gt(preIndex);
    expect(posIndex).to.be.eq(await yieldToken.callStatic.exchangeRateCurrent());
  });

  it('Lyt index current - Exchange rate decrease', async () => {
    await lyt.lyt.lytIndexCurrent();
    const preIndex = await lyt.lyt.callStatic.lytIndexCurrent();
    await fakeReduceExchangeRate();
    const postIndex = await lyt.lyt.callStatic.lytIndexCurrent();
    const qiIndex = await yieldToken.callStatic.exchangeRateCurrent();

    expect(qiIndex).to.be.lt(postIndex);
    expect(postIndex).to.be.eq(preIndex);
  });

  it('Lyt index stored', async () => {
    await lyt.lyt.lytIndexCurrent();
    const preIndex = await lyt.lyt.lytIndexStored();
    await lyt.addFakeIncome(env);

    expect(await lyt.lyt.lytIndexStored()).to.be.eq(preIndex);
  });

  /*///////////////////////////////////////////////////////////////
                MISC METADATA FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  it('Decimal', async () => {
    expect(await lyt.lyt.decimals()).to.be.eq(LYT_DECIMAL);
  });

  it('Asset decimal', async () => {
    expect(await lyt.lyt.assetDecimals()).to.be.eq(await underlying.decimals());
  });

  it('Base tokens', async () => {
    expect(await lyt.lyt.getBaseTokens()).to.be.eql([underlying.address]);
  });

  it('Check valid base token', async () => {
    expect(await lyt.lyt.isValidBaseToken(underlying.address)).to.be.true;
    expect(await lyt.lyt.isValidBaseToken(alice.address)).to.be.false;
  });

  /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

  it('Get reward tokens', async () => {
    expect(await lyt.lyt.getRewardTokens()).to.be.eql(lytRewardsTokens);
  });

  it('Redeem rewards success', async () => {
    await lyt.depositBaseToken(alice, underlying.address, REF_AMOUNT_WEI);
    await advanceTime(env.aconsts.misc.ONE_DAY);

    const directRewards = await getRewardAmount(
      alice,
      rewardTokens,
      async () => await lyt.claimDirectReward(bob, alice)
    );

    const lytRewards = await getRewardAmount(
      alice,
      lytRewardsTokens,
      async () => await lyt.redeemReward(bob, alice.address)
    );

    // possible delay in one minute reward between txn
    for (let i = 0; i < directRewards.length; ++i) {
      approxBigNumber(directRewards[i], lytRewards[i], directRewards[i].div(MINUTES_PER_DAY));
    }
  });

  /*///////////////////////////////////////////////////////////////
                            TRANSFER HOOKS
    //////////////////////////////////////////////////////////////*/

  it('Lyt balance after transfer', async () => {
    const initialBal = await lyt.yieldTokenBalance(alice.address);
    await lyt.depositYieldToken(alice, initialBal);
    await lyt.transfer(alice, bob.address, initialBal);

    expect(await lyt.balanceOf(alice.address)).to.be.eq(0);
    expect(await lyt.balanceOf(bob.address)).to.be.eq(initialBal);

    await lyt.redeemYieldToken(bob, initialBal);

    expect(await lyt.yieldTokenBalance(bob.address)).to.be.eq(initialBal);
  });

  it('Reward calculated to original user after transfer', async () => {
    await lyt.depositBaseToken(alice, underlying.address, REF_AMOUNT_WEI);
    await advanceTime(env.aconsts.misc.ONE_DAY);

    const lytBal = await lyt.balanceOf(alice.address);
    expect(lytBal).to.be.gt(0);
    await lyt.transfer(alice, bob.address, lytBal);

    const directRewards = await getRewardAmount(
      alice,
      rewardTokens,
      async () => await lyt.claimDirectReward(bob, alice)
    );

    const lytRewards_Bob = await getRewardAmount(
      bob,
      lytRewardsTokens,
      async () => await lyt.redeemReward(alice, bob.address)
    );

    const lytRewards = await getRewardAmount(
      alice,
      lytRewardsTokens,
      async () => await lyt.redeemReward(bob, alice.address)
    );

    // possible delay in one minute reward between txn
    for (let i = 0; i < directRewards.length; ++i) {
      approxBigNumber(directRewards[i], lytRewards[i], directRewards[i].div(MINUTES_PER_DAY));
      expect(lytRewards_Bob[i]).to.be.lte(lytRewards[i].div(MINUTES_PER_DAY));
    }
  });

  it('Reward claimed after redeem', async () => {
    await lyt.depositBaseToken(alice, underlying.address, REF_AMOUNT_WEI);
    await advanceTime(env.aconsts.misc.ONE_DAY);

    await lyt.redeemYieldToken(alice, await lyt.balanceOf(alice.address));

    const directRewards = await getRewardAmount(
      alice,
      rewardTokens,
      async () => await lyt.claimDirectReward(bob, alice)
    );

    const lytRewards = await getRewardAmount(
      alice,
      lytRewardsTokens,
      async () => await lyt.redeemReward(bob, alice.address)
    );

    // possible delay in one minute reward between txn
    for (let i = 0; i < directRewards.length; ++i) {
      approxBigNumber(directRewards[i], lytRewards[i], directRewards[i].div(MINUTES_PER_DAY));
    }
  });

  /*///////////////////////////////////////////////////////////////
                            STRESS TESTS
    //////////////////////////////////////////////////////////////*/

  it('Stress test rewards', async () => {
    const NUM_ITERS = 10;

    await fundToken(env, [charlie.address], underlying.address, REF_AMOUNT_WEI);

    const smallAmount = REF_AMOUNT_WEI.div(NUM_ITERS);

    for (let i = 0; i < NUM_ITERS; ++i) {
      const amount = smallAmount.mul(random(1, 100)).div(100);
      const time_type = random(0, 3);
      await lyt.depositBaseToken(alice, underlying.address, amount);
      await lyt.mintYieldToken(charlie, amount);

      let time: BN = BN.from(0);
      switch (time_type) {
        case 0:
          time = env.mconsts.ONE_DAY;
          break;
        case 1:
          time = env.mconsts.ONE_WEEK;
          break;
        case 2:
          time = env.mconsts.ONE_MONTH;
          break;
      }
      await advanceTime(time);
    }

    const directRewards = await getRewardAmount(
      charlie,
      rewardTokens,
      async () => await lyt.claimDirectReward(bob, charlie)
    );

    const lytRewards = await getRewardAmount(
      alice,
      lytRewardsTokens,
      async () => await lyt.redeemReward(bob, alice.address)
    );

    for (let i = 0; i < directRewards.length; ++i) {
      approxBigNumber(directRewards[i], lytRewards[i], directRewards[i].div(MINUTES_PER_MONTH));
    }
  });
});
