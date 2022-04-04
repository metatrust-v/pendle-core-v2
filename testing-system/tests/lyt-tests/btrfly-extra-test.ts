import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber as BN } from 'ethers';
import { ERC20 } from '../../../typechain-types';
import { LytSingle, TestEnv } from '../../environment';
import { BtrflyLyt } from '../../environment/fixtures/ethereum/btrflySupport';
import { LYTSimpleInterface } from '../../environment/lyt-testing-interfaces/simple-interfaces';
import {
  approveAll,
  approxBigNumber,
  approxByPercent,
  evm_revert,
  evm_snapshot,
  fundToken,
} from '../../helpers';
import hre from 'hardhat';
import { expect } from 'chai';

export async function runExtraTestBtrfly<LYT extends LytSingle<LYTSimpleInterface>>(
  env: TestEnv,
  lyt: BtrflyLyt
) {
  describe('Btrfly lyt extra test', async () => {
    const LYT_DECIMAL = 18;

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
    let xBTRFLY: ERC20;

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
      xBTRFLY = lyt.xBTRFLY;
    }

    async function prepTestScenerio() {
      await approveAll(env, underlying.address, lyt.address);
      await approveAll(env, underlying.address, yieldToken.address);
      await approveAll(env, yieldToken.address, lyt.address);
      await fundToken(
        env,
        wallets.map((v) => v.address),
        underlying.address,
        REF_AMOUNT_WEI.mul(2)
      );
    }

    async function mintFromXBtrfly(payer: SignerWithAddress, recipient: string, amount: BN) {
      await xBTRFLY.connect(payer).transfer(lyt.address, amount);
      let preBal = await lyt.balanceOf(recipient);
      await lyt.lyt.connect(payer).mint(recipient, xBTRFLY.address, 0);
      return (await lyt.balanceOf(recipient)).sub(preBal);
    }

    async function redeemToXBtrfly(payer: SignerWithAddress, recipient: string, amount: BN) {
      await lyt.lyt.connect(payer).transfer(lyt.address, amount);
      let preBal = await xBTRFLY.balanceOf(recipient);
      await lyt.lyt.connect(payer).redeem(recipient, xBTRFLY.address, 0);
      return (await xBTRFLY.balanceOf(recipient)).sub(preBal);
    }

    it('Deposit & redeem using xBtrfly', async () => {
      /*                      PHASE 1: Deposit using underlying                         */
      const exchangeRateStart = await lyt.indexCurrent();
      const expectedLytAmount = REF_AMOUNT_WEI.mul(2)
        .mul(env.mconsts.ONE_E_18)
        .div(exchangeRateStart);
      for (let i = 0; i < wallets.length; ++i) {
        const pi = wallets[i];
        const pj = wallets[(i + 1) % wallets.length];
        await lyt.mint(pi, pi.address, underlying.address, REF_AMOUNT_WEI);
        await lyt.mint(pj, pj.address, underlying.address, REF_AMOUNT_WEI);
      }

      /*                      PHASE 2: Redeem Lyt to xBtrfly                         */
      for (let i = 0; i < wallets.length; ++i) {
        const pi = wallets[i];
        const pj = wallets[(i + 1) % wallets.length];
        const bal = await lyt.balanceOf(pi.address);
        await redeemToXBtrfly(pi, pi.address, bal.div(2));
        await redeemToXBtrfly(pi, pj.address, bal.div(2));
      }
      for (let person of wallets) {
        approxBigNumber(await xBTRFLY.balanceOf(person.address), REF_AMOUNT_WEI.mul(2), 10);
      }

      /*                      PHASE 3: Deposit xBtrfly to lyt                         */
      for (let i = 0; i < wallets.length; ++i) {
        const pi = wallets[i];
        const pj = wallets[(i + 1) % wallets.length];
        const bal = await xBTRFLY.balanceOf(pi.address);
        await mintFromXBtrfly(pi, pi.address, bal.div(2));
        await mintFromXBtrfly(pi, pj.address, bal.div(2));
      }

      const delta = 10 ** ((await lyt.lyt.decimals()) - (await xBTRFLY.decimals()) + 1);
      for (let person of wallets) {
        approxBigNumber(await lyt.balanceOf(person.address), expectedLytAmount, delta);
      }
    });

    it('Check xBTRFLY is valid base token', async () => {
      expect(await lyt.lyt.isValidBaseToken(xBTRFLY.address)).to.be.true;
    });
  });
}
