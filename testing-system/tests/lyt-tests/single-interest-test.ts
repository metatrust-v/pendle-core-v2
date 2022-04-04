import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber as BN } from 'ethers';
import { ERC20 } from '../../../typechain-types';
import { buildEnv, LytSingle, Network, TestEnv } from '../../environment';
import { parseLYTSingleEnv } from '../../environment/fixtures';
import { LYTSimpleInterface } from '../../environment/lyt-testing-interfaces/simple-interfaces';
import {
  advanceTime,
  approxByPercent,
  clearFund,
  evm_revert,
  evm_snapshot,
  fundToken,
  getSumBalance,
  minBN,
  random,
} from '../../helpers';

export async function runTest<LYT extends LytSingle<LYTSimpleInterface>>(
  env: TestEnv,
  lyt: LYT
): Promise<void> {
  describe('Lyt single underlying test', async () => {
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
        REF_AMOUNT_WEI.mul(200)
      );
    });

    after(async () => {
      await evm_revert(globalSnapshotId);
    });

    it('Holding LYT should gives the same amount of interest as holding yieldToken', async () => {
      await clearFund(env, wallets, [yieldToken.address, lyt.address, underlying.address]);
      const NUM_ITERS = 20;

      let funded = BN.from(0);

      for (let iter = 0; iter < NUM_ITERS; ++iter) {
        let action = iter == 0 ? 0 : random(0, 2);
        let i1 = random(0, 2);
        let i2 = random(2, 5);

        if (action == 0) {
          // DEPOSIT
          funded = funded.add(REF_AMOUNT_WEI.mul(2));
          await fundToken(
            env,
            [wallets[i1].address, wallets[i2].address],
            underlying.address,
            REF_AMOUNT_WEI.mul(2)
          );
          await lyt.mintYieldToken(wallets[i1], REF_AMOUNT_WEI);
          await lyt.mint(wallets[i2], wallets[i2].address, underlying.address, REF_AMOUNT_WEI);
        } else {
          let delta = minBN(
            await yieldToken.balanceOf(wallets[i1].address),
            await lyt.balanceOf(wallets[i2].address)
          );
          if (delta.gt(0)) {
            await lyt.burnYieldToken(wallets[i1], delta);
            await lyt.redeem(wallets[i2], wallets[i2].address, underlying.address, delta);
          }
        }

        let j1 = i1 == 0 ? 1 : 0;
        let j2 = i2 == 2 ? 3 : i2 - 1;
        let delta = minBN(
          await yieldToken.balanceOf(wallets[j1].address),
          await lyt.balanceOf(wallets[j2].address)
        ).div(2);
        if (delta.gt(0)) {
          await yieldToken.connect(wallets[j1]).transfer(wallets[i1].address, delta);
          await lyt.transfer(wallets[j2], wallets[i2].address, delta);
        }
        await advanceTime(env.mconsts.ONE_MONTH);
        await lyt.addFakeIncome(env);
      }

      for (let i = 0; i < wallets.length; ++i) {
        if (i < 2) {
          await lyt.burnYieldToken(wallets[i], await yieldToken.balanceOf(wallets[i].address));
        } else {
          await lyt.redeem(
            wallets[i],
            wallets[i].address,
            underlying.address,
            await lyt.balanceOf(wallets[i].address)
          );
        }
      }

      const balAliceBob = await getSumBalance(
        [wallets[0].address, wallets[1].address],
        underlying.address
      );
      
      // interest should yield more underlying overtime
      expect(balAliceBob).to.be.gt(funded);
      console.log('Funded:', funded.toString());
      console.log('After-interest:', balAliceBob.toString());

      approxByPercent(
        balAliceBob,
        await getSumBalance(
          [wallets[2].address, wallets[3].address, wallets[4].address],
          underlying.address
        )
      );
    });
  });
}

it('Run test single', async () => {
  const env = await buildEnv();
  if (env.network == Network.AVAX) {
    await runTest(env, env.qiLyt);
  } else if (env.network == Network.ETH) {
    await runTest(env, env.btrflyLyt);
  } else {
    throw new Error('Unsupported Network');
  }
});
