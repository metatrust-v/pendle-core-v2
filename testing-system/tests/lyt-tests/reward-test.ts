import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber as BN } from 'ethers';
import hre from 'hardhat';
import { ERC20 } from '../../../typechain-types';
import { buildEnv, LytSingleReward, TestEnv } from '../../environment';
import { LYTRewardSimpleInterface } from '../../environment/lyt-testing-interfaces/simple-interfaces';
import {
  advanceTime,
  approveAll,
  approxBigNumber,
  approxByPercent,
  evm_revert,
  evm_snapshot,
  fundToken,
  minBN,
  random,
  setTimeNextBlock,
} from '../../helpers';

export async function runTest<LYT extends LytSingleReward<LYTRewardSimpleInterface>>(env: TestEnv, lyt: LYT) {
  describe('LYT reward testing', async () => {
    const [ALICE, LYT] = [0, 1];
    const LYT_DECIMAL = 18;
    const MINUTES_PER_DAY = 1440;
    const MINUTES_PER_MONTH = MINUTES_PER_DAY * 30;

    let globalSnapshotId: string;
    let snapshotId: string;
    let wallets: SignerWithAddress[];

    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let charlie: SignerWithAddress;
    let dave: SignerWithAddress;
    let eve: SignerWithAddress;

    let REF_AMOUNT: BN;
    let REF_AMOUNT_WEI: BN;

    let underlying: ERC20;
    let yieldToken: ERC20;
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
      [alice, bob, charlie, dave, eve] = wallets = await hre.ethers.getSigners();
      REF_AMOUNT = BN.from(10 ** 2);
      REF_AMOUNT_WEI = REF_AMOUNT.mul(BN.from(10).pow(await lyt.underlying.decimals()));
      underlying = lyt.underlying;
      yieldToken = lyt.yieldToken;
      allContracts = [alice.address, lyt.lyt.address];
    }

    async function prepTestScenerio() {
      await approveAll(env, underlying.address, lyt.lyt.address);
      await approveAll(env, underlying.address, yieldToken.address);
      await approveAll(env, yieldToken.address, lyt.lyt.address);
      await fundToken(
        env,
        wallets.map((v) => v.address),
        underlying.address,
        REF_AMOUNT_WEI.mul(2)
      );
    }

    async function getRewardBalances(peopleIds: number[], rwdId: number = 0): Promise<BN> {
      let res = BN.from(0);
      for(let id of peopleIds) {
        res = res.add(await lyt.rewardBalance(wallets[id].address, rwdId));
      }
      return res;
    }

    async function getRewardAmount(person: SignerWithAddress, getReward: any) {
      const res: BN[] = [];
      for (let i = 0; i < lyt.rewardTokens.length; ++i) {
        res.push(await lyt.rewardBalance(person.address, i));
      }
      await getReward();
      for (let i = 0; i < lyt.rewardTokens.length; ++i) {
        res[i] = (await lyt.rewardBalance(person.address, i)).sub(res[i]);
      }
      return res;
    }

    it.only('Redeem rewards success', async () => {
      await lyt.mintYieldToken(charlie, REF_AMOUNT_WEI.mul(2));

      let currentTime = BN.from(Math.round(new Date().getTime() / 1000));
      await setTimeNextBlock(currentTime.add(env.mconsts.ONE_DAY));
      await lyt.depositBaseToken(alice, underlying.address, REF_AMOUNT_WEI);
      currentTime = currentTime.add(env.mconsts.ONE_DAY);

      await setTimeNextBlock(currentTime.add(env.mconsts.ONE_DAY));
      await yieldToken.connect(charlie).transfer(bob.address, await lyt.balanceOf(alice.address));
      currentTime = currentTime.add(env.mconsts.ONE_DAY);

      await setTimeNextBlock(currentTime.add(env.mconsts.ONE_WEEK));
      const lytRewards = await getRewardAmount(alice, async () => await lyt.redeemReward(alice, alice.address));
      currentTime = currentTime.add(env.mconsts.ONE_WEEK);

      await setTimeNextBlock(currentTime.add(env.mconsts.ONE_DAY));
      const directRewards = await getRewardAmount(bob, async () => await lyt.claimDirectReward(bob, bob.address));
      currentTime = currentTime.add(env.mconsts.ONE_DAY);

      // possible delay in one minute reward between txn
      for (let i = 0; i < directRewards.length-1; ++i) {
        approxBigNumber(directRewards[i], lytRewards[i], 10);
      }
    });

    // /*///////////////////////////////////////////////////////////////
    //                           STRESS TEST
    //   //////////////////////////////////////////////////////////////*/

    it('Lyt holders should receive the same amount of rewards compared to yieldToken holders', async() => {
      return;
      await fundToken(env, wallets.map(v => v.address), underlying.address, REF_AMOUNT_WEI.mul(100));
      /**
       * P1s holding yield bearing, P2s holding LYT
       */
      const NUM_ITERS = 50;
      for(let iter = 0; iter < NUM_ITERS; ++iter) {
        let action = random(0, 2);

        let p1 = wallets[random(0, 3)]; 
        let p2 = wallets[3 + random(0, 2)];

        if (action == 0) { // MINT
          await lyt.depositBaseToken(p1, underlying.address, REF_AMOUNT_WEI);
          await lyt.mintYieldToken(p2, REF_AMOUNT_WEI);
        } else { // BURN
          let delta = minBN(await lyt.balanceOf(p1.address), await yieldToken.balanceOf(p2.address));
          if (delta.gt(0)) {
            await lyt.redeemBaseToken(p1, underlying.address, delta);
            await lyt.burnYieldToken(p2, delta);
          }
        }
        
        let transferer = random(0, 2);
        let receiver = transferer ^ 1;
        let lytBal = await lyt.balanceOf(wallets[transferer].address);
        if (lytBal.gt(0)) {
          await lyt.transfer(wallets[transferer], wallets[receiver].address, lytBal.div(2));
        }
        await advanceTime(env.mconsts.ONE_WEEK);
      }

      for(let person of wallets) {
        await lyt.claimDirectReward(person, person.address);
        await lyt.redeemReward(person, person.address);
      }

      approxByPercent(
        await getRewardBalances([0, 1, 2]),
        await getRewardBalances([3, 4])
      );
    });

    it('Lyt holders receive reward proportionally to their balances', async() => {
      return;
      await fundToken(env, wallets.map(v => v.address), underlying.address, REF_AMOUNT_WEI.mul(100));
      /**
       * Scenario: alice + bob = charlie + dave = eve
       */
      const NUM_ITERS = 50;
      for(let iter = 0; iter < NUM_ITERS; ++iter) {
        let action = random(0, 2);
        let p1 = wallets[random(0, 2)]; 
        let p2 = wallets[random(2, 4)];
        let p3 = eve;
  
        if (action == 0) { // MINT
          for(let person of [p1, p2, p3]) {
            await lyt.depositBaseToken(person, underlying.address, REF_AMOUNT_WEI);
          }
        } else { // BURN
          let delta = minBN(await lyt.balanceOf(p1.address), minBN(await lyt.balanceOf(p2.address), await lyt.balanceOf(p3.address)));
          if (delta.gt(0)) {
            for(let person of [p1, p2, p3]) {
              await lyt.redeemBaseToken(person, underlying.address, delta.div(2));
            }
          }
        }
        await advanceTime(env.mconsts.ONE_WEEK);
      }
  
      for(let person of wallets) {
        await lyt.claimDirectReward(person, person.address);
        await lyt.redeemReward(person, person.address);
      }
  
      approxByPercent(
        await getRewardBalances([0, 1]),
        await getRewardBalances([2, 3])
      );
      approxByPercent(
        await getRewardBalances([0, 1]),
        await getRewardBalances([4])
      );
    });
  });
}

it('Run reward tests', async () => {
  const env = await buildEnv();
  await runTest(env, env.qiLyt);
});
