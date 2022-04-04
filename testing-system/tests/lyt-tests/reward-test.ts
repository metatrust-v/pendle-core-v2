import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber as BN } from 'ethers';
import hre from 'hardhat';
import { exit } from 'process';
import { ERC20 } from '../../../typechain-types';
import { buildEnv, LytSingleReward, TestEnv } from '../../environment';
import { parseLYTSingleEnv } from '../../environment/fixtures';
import { LYTRewardSimpleInterface } from '../../environment/lyt-testing-interfaces/simple-interfaces';
import {
  advanceTime,
  approveAll,
  approxBigNumber,
  approxByPercent,
  clearFund,
  evm_revert,
  evm_snapshot,
  fundToken,
  getSumBalance,
  minBN,
  random,
  setTimeNextBlock,
} from '../../helpers';

export async function runTest<LYT extends LytSingleReward<LYTRewardSimpleInterface>>(
  env: TestEnv,
  lyt: LYT
) {
  describe('LYT reward testing', async () => {
    let globalSnapshotId: string;
    let snapshotId: string;
    let wallets: SignerWithAddress[];

    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let charlie: SignerWithAddress;
    let dave: SignerWithAddress;
    let eve: SignerWithAddress;

    let REF_AMOUNT_WEI: BN;

    let underlying: ERC20;
    let yieldToken: ERC20;

    /*///////////////////////////////////////////////////////////////
														Setting up
		//////////////////////////////////////////////////////////////*/
    before(async () => {
      globalSnapshotId = await evm_snapshot();
      snapshotId = await evm_snapshot();
      [alice, bob, charlie, dave, eve] = wallets = env.wallets;
    });

    beforeEach(async () => {
      await evm_revert(snapshotId);
      snapshotId = await evm_snapshot();
      env = await parseLYTSingleEnv(env, lyt);
      ({ underlying, yieldToken, REF_AMOUNT_WEI } = env);
      await fundToken(
        env,
        wallets.map((v) => v.address),
        underlying.address,
        REF_AMOUNT_WEI.mul(2)
      );
    });

    after(async () => {
      await evm_revert(globalSnapshotId);
    });

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

    it('Redeem rewards success, [Charlie and dave pays all for alice and bob]', async () => {
      await clearFund(env, [alice, bob], [underlying.address, yieldToken.address]);
      await lyt.mintYieldToken(charlie, REF_AMOUNT_WEI.mul(2));
      let currentTime = BN.from(Math.round(new Date().getTime() / 1000));
      await setTimeNextBlock(currentTime.add(env.mconsts.ONE_DAY));
      await lyt.mint(dave, alice.address, underlying.address, REF_AMOUNT_WEI);
      currentTime = currentTime.add(env.mconsts.ONE_DAY);

      await setTimeNextBlock(currentTime.add(env.mconsts.ONE_DAY));
      await yieldToken.connect(charlie).transfer(bob.address, await lyt.balanceOf(alice.address));
      currentTime = currentTime.add(env.mconsts.ONE_DAY);

      await setTimeNextBlock(currentTime.add(env.mconsts.ONE_WEEK));
      const lytRewards = await getRewardAmount(
        alice,
        async () => await lyt.redeemReward(alice, alice.address)
      );
      currentTime = currentTime.add(env.mconsts.ONE_WEEK);

      await setTimeNextBlock(currentTime.add(env.mconsts.ONE_DAY));
      const directRewards = await getRewardAmount(
        bob,
        async () => await lyt.claimDirectReward(bob, bob.address)
      );
      currentTime = currentTime.add(env.mconsts.ONE_DAY);

      // possible delay in one minute reward between txn
      for (let i = 0; i < directRewards.length - 1; ++i) {
        approxByPercent(directRewards[i], lytRewards[i], 10);
      }
    });

    // /*///////////////////////////////////////////////////////////////
    //                           STRESS TEST
    //   //////////////////////////////////////////////////////////////*/

    it('Lyt holders should receive the same amount of rewards compared to yieldToken holders', async () => {
      await fundToken(
        env,
        wallets.map((v) => v.address),
        underlying.address,
        REF_AMOUNT_WEI.mul(100)
      );
      /**
       * P1s holding yield bearing, P2s holding LYT
       */
      const NUM_ITERS = 40;
      for (let iter = 0; iter < NUM_ITERS; ++iter) {
        let action = random(0, 2);

        let p1 = wallets[random(0, 3)];
        let p2 = wallets[3 + random(0, 2)];

        if (action == 0) {
          // MINT
          await lyt.mint(p1, p1.address, underlying.address, REF_AMOUNT_WEI);
          await lyt.mintYieldToken(p2, REF_AMOUNT_WEI);
        } else {
          // BURN
          let delta = minBN(
            await lyt.balanceOf(p1.address),
            await yieldToken.balanceOf(p2.address)
          );
          if (delta.gt(0)) {
            await lyt.redeem(p1, p1.address, underlying.address, delta);
            await lyt.burnYieldToken(p2, delta);
          }
        }

        let transferer = random(0, 2);
        let receiver = transferer ^ 1;
        let lytBal = await lyt.balanceOf(wallets[transferer].address);
        if (lytBal.gt(0)) {
          await lyt.transfer(wallets[transferer], wallets[receiver].address, lytBal.div(2));
        }
        await advanceTime(env.mconsts.ONE_DAY);
      }

      for (let i = 0; i < wallets.length; ++i) {
        let person = wallets[i];
        if (i < 3) await lyt.redeemReward(person, person.address);
        else await lyt.claimDirectReward(person, person.address);
      }



      approxByPercent(
        await getSumBalance(
          [wallets[0].address, wallets[1].address, wallets[2].address],
          lyt.rewardTokens[0].address
        ),
        await getSumBalance([wallets[3].address, wallets[4].address], lyt.rewardTokens[0].address)
      );
    });

    it('Lyt holders receive reward proportionally to their balances', async () => {
      await fundToken(
        env,
        wallets.map((v) => v.address),
        underlying.address,
        REF_AMOUNT_WEI.mul(100)
      );
      /**
       * Scenario: alice + bob = charlie + dave = eve
       */
      const NUM_ITERS = 50;
      for (let iter = 0; iter < NUM_ITERS; ++iter) {
        let action = random(0, 2);
        let p1 = wallets[random(0, 2)];
        let p2 = wallets[random(2, 4)];
        let p3 = eve;

        if (action == 0) {
          // MINT
          for (let person of [p1, p2, p3]) {
            await lyt.mint(person, person.address, underlying.address, REF_AMOUNT_WEI);
          }
        } else {
          // BURN
          let delta = minBN(
            await lyt.balanceOf(p1.address),
            minBN(await lyt.balanceOf(p2.address), await lyt.balanceOf(p3.address))
          );
          if (delta.gt(0)) {
            for (let person of [p1, p2, p3]) {
              await lyt.redeem(person, person.address, underlying.address, delta.div(2));
            }
          }
        }
        await advanceTime(env.mconsts.ONE_DAY);
      }

      for (let person of wallets) {
        await lyt.redeemReward(person, person.address);
      }

      approxByPercent(
        await getSumBalance([wallets[0].address, wallets[1].address], lyt.rewardTokens[0].address),
        await getSumBalance([wallets[2].address, wallets[3].address], lyt.rewardTokens[0].address)
      );

      approxByPercent(
        await getSumBalance([wallets[0].address, wallets[1].address], lyt.rewardTokens[0].address),
        await getSumBalance([wallets[4].address], lyt.rewardTokens[0].address)
      );
    });
  });
}
