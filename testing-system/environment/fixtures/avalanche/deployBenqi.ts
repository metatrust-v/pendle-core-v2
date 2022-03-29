import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber as BN } from 'ethers';
import { LytSingleReward } from '../../lyt-testing-interfaces';
import {
  BenqiChainlinkOracle,
  Comptroller,
  ERC20,
  ERC20Premined,
  JumpRateModel,
  PendleBenQiErc20LYT,
  QiErc20,
  QiErc20Delegate,
  QiErc20Delegator,
  Unitroller,
} from '../../../../typechain-types';
import { approveAll, deploy, getContractAt, transferNative } from '../../../helpers';
import { TestEnv } from '../..';

export class BenqiLyt extends LytSingleReward<PendleBenQiErc20LYT> {
  qiToken: QiErc20 = {} as QiErc20;
  comptroller: Comptroller = {} as Comptroller;

  constructor(lyt: PendleBenQiErc20LYT) {
    super(lyt);
  }

  public async initialize(): Promise<void> {
    await super.initialize();
    this.qiToken = await getContractAt<QiErc20>('QiErc20', await this.lyt.qiToken());
    this.comptroller = await getContractAt<Comptroller>('Comptroller', await this.qiToken.comptroller());
    this.underlying = await getContractAt<ERC20>('ERC20', await this.qiToken.underlying());
    this.yieldToken = await getContractAt<ERC20>('ERC20', this.qiToken.address);
  }

  async mintYieldToken(person: SignerWithAddress, amount: BN): Promise<void> {
    await this.qiToken.connect(person).mint(amount);
  }
  async burnYieldToken(person: SignerWithAddress, amount: BN): Promise<void> {
    await this.qiToken.connect(person).redeem(amount);
  }
  async addFakeIncome(env: TestEnv): Promise<void> {
    const currentBal = await this.underlying.balanceOf(this.qiToken.address);
    await env.fundKeeper.transferTo(this.underlying.address, this.qiToken.address, currentBal.div(10));
  }
  async yieldTokenBalance(addr: string): Promise<BN> {
    return await this.qiToken.balanceOf(addr);
  }

  async claimDirectReward(payer: SignerWithAddress, addr: string): Promise<void> {
    for (let i = 0; i < 2; ++i) {
      await this.comptroller.connect(payer)['claimReward(uint8,address)'](i, addr);
    }
  }

  async getDirectExchangeRate(): Promise<BN> {
    return await this.qiToken.callStatic.exchangeRateCurrent();
  }
}

export interface BenqiEnv {
  qiUSDC: QiErc20;
  qiLyt: BenqiLyt;
  qiToken: ERC20Premined;
}

export async function deployBenqi(env: TestEnv): Promise<BenqiEnv> {
  const comptrollerImplementation = await deploy<Comptroller>(env.deployer, 'Comptroller', []);
  const unitroller = await deploy<Unitroller>(env.deployer, 'Unitroller', []);
  await unitroller._setPendingImplementation(comptrollerImplementation.address);
  await comptrollerImplementation._become(unitroller.address);

  const comptroller = await getContractAt<Comptroller>('Comptroller', unitroller.address);

  // FUND REWARD
  const qiToken = await deploy<ERC20Premined>(env.deployer, 'ERC20Premined', ['Qi', 18]);
  await comptroller.setQiAddress(qiToken.address);
  await qiToken.transfer(comptroller.address, await qiToken.balanceOf(env.deployer.address));
  await transferNative(env.deployer, comptroller.address, env.mconsts.ONE_E_18.mul(10 ** 6));

  // DEPLOY TOKEN
  const interestRateModel = await deploy<JumpRateModel>(env.deployer, 'JumpRateModel', [
    BN.from(10).pow(16).mul(2),
    BN.from(10).pow(17),
    BN.from(10).pow(16).mul(109),
    BN.from(10).pow(17).mul(8),
  ]);

  const qiErc20Implementation = await deploy<QiErc20Delegate>(env.deployer, 'QiErc20Delegate', []);
  const qiUSD = await deploy<QiErc20Delegator>(env.deployer, 'QiErc20Delegator', [
    env.tokens.USD.address,
    comptroller.address,
    interestRateModel.address,
    env.mconsts.ONE_E_18,
    'qiUSD',
    'qiUSD',
    8,
    env.deployer.address,
    qiErc20Implementation.address,
    '0x',
  ]);
  await approveAll(env, env.tokens.USD.address, qiUSD.address);

  // SET UP TOKEN
  await comptroller._supportMarket(qiUSD.address);
  const oracle = await deploy<BenqiChainlinkOracle>(env.deployer, 'BenqiChainlinkOracle', []);
  await oracle.setUnderlyingPrice(qiUSD.address, env.mconsts.ONE_E_18);
  await comptroller._setPriceOracle(oracle.address);
  await comptroller._setCollateralFactor(qiUSD.address, env.mconsts.ONE_E_18.mul(8).div(10));
  await comptroller._setRewardSpeed(0, qiUSD.address, env.mconsts.ONE_E_18);
  await comptroller._setRewardSpeed(1, qiUSD.address, env.mconsts.ONE_E_18);

  // FAKE AMOUNT
  await env.fundKeeper.depositBenqi(qiUSD.address, BN.from(10).pow(10));

  // Deploy LYT
  const lyt = await deploy<PendleBenQiErc20LYT>(env.deployer, 'PendleBenQiErc20LYT', [
    'LYT-qiUSD',
    'LYT-qiUSD',
    18,
    6,
    env.tokens.USD.address,
    qiUSD.address,
    comptroller.address,
    qiToken.address,
    env.aconsts.tokens.WNATIVE.address,
  ]);

  const qiLyt: BenqiLyt = new BenqiLyt(lyt);
  await qiLyt.initialize();

  return {
    qiUSDC: qiUSD as any as QiErc20,
    qiLyt: qiLyt,
    qiToken: qiToken,
  };
}
