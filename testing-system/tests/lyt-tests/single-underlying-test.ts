import { evm_revert, evm_snapshot, approxBigNumber, approveAll, fundToken } from '../../helpers';
import { buildEnv, LytSingle, TestEnv } from '../../environment';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber as BN } from 'ethers';
import hre from 'hardhat';
import { ERC20 } from '../../../typechain-types';
import { expect } from 'chai';
import { LYTSimpleInterface } from '../../environment/lyt-testing-interfaces/simple-interfaces';

export async function runTest<LYT extends LytSingle<LYTSimpleInterface>>(env: TestEnv, lyt: LYT) {
  describe('Benqi-lyt test', async () => {
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

    /*///////////////////////////////////////////////////////////////
                            DEPOSIT & REDEEM 
      //////////////////////////////////////////////////////////////*/

    it('Deposit & redeem test', async () => {
      /*                      PHASE 1: Deposit using underlying                         */
      const exchangeRateStart = await lyt.indexCurrent();
      const expectedLytAmount = REF_AMOUNT_WEI.mul(2).mul(env.mconsts.ONE_E_18).div(exchangeRateStart);
      for (let i = 0; i < wallets.length; ++i) {
        const pi = wallets[i];
        const pj = wallets[(i + 1) % wallets.length];
        await lyt.depositBaseToken(pi, underlying.address, REF_AMOUNT_WEI);
        await lyt.depositBaseTokenFor(pj, pj.address, underlying.address, REF_AMOUNT_WEI);
      }
      for (let person of wallets) {
        approxBigNumber(await lyt.balanceOf(person.address), expectedLytAmount, 10);
      }

      /*                      PHASE 2: Redeem Lyt to yieldToken                         */
      for (let i = 0; i < wallets.length; ++i) {
        const pi = wallets[i];
        const pj = wallets[(i + 1) % wallets.length];
        const bal = await lyt.balanceOf(pi.address);
        await lyt.redeemYieldToken(pi, bal.div(2));
        await lyt.redeemYieldTokenFor(pi, pj.address, bal.div(2));
      }
      for (let person of wallets) {
        approxBigNumber(await yieldToken.balanceOf(person.address), expectedLytAmount, 10);
      }

      /*                      PHASE 3: Deposit yieldToken to lyt                         */
      for (let i = 0; i < wallets.length; ++i) {
        const pi = wallets[i];
        const pj = wallets[(i + 1) % wallets.length];
        const bal = await yieldToken.balanceOf(pi.address);
        await lyt.depositYieldToken(pi, bal.div(2));
        await lyt.depositYieldTokenFor(pi, pj.address, bal.div(2));
      }
      for (let person of wallets) {
        approxBigNumber(await lyt.balanceOf(person.address), expectedLytAmount, 10);
      }

      /*                      PHASE 4: Redeem Lyt to underlying                         */
      for (let i = 0; i < wallets.length; ++i) {
        const pi = wallets[i];
        const pj = wallets[(i + 1) % wallets.length];
        const bal = await lyt.balanceOf(pi.address);
        await lyt.redeemBaseToken(pi, underlying.address, bal.div(4));
        await lyt.redeemBaseTokenFor(pi, pj.address, underlying.address, bal.div(4));
      }

      for (let person of wallets) {
        approxBigNumber(await lyt.balanceOf(person.address), expectedLytAmount.div(2), 10);
        approxBigNumber(await underlying.balanceOf(person.address), REF_AMOUNT_WEI, 10);
      }
    });
    /*///////////////////////////////////////////////////////////////
                                 LYT-INDEX
      //////////////////////////////////////////////////////////////*/

    it('Asset balance', async () => {
      await lyt.mintYieldToken(alice, REF_AMOUNT_WEI);
      await lyt.depositBaseToken(alice, underlying.address, REF_AMOUNT_WEI);
      expect(await underlying.balanceOf(alice.address)).to.be.equal(0);
      await lyt.burnYieldToken(alice, await yieldToken.balanceOf(alice.address));
      approxBigNumber(await lyt.assetBalanceOf(alice.address), await underlying.balanceOf(alice.address), 10);
    });

    it('Lyt index current', async () => {
      const preIndex = await lyt.indexCurrent();
      await lyt.addFakeIncome(env);
      const postIndex = await lyt.indexCurrent();
      expect(postIndex).to.be.gt(preIndex);
      expect(postIndex).to.be.eq(await lyt.getDirectExchangeRate());
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
  });
}

it('Run test single', async () => {
  const env = await buildEnv();
  await runTest(env, env.qiLyt);
});
