import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber as BN, BigNumberish } from 'ethers';
import { LytSingleReward } from '../../lyt-testing-interfaces';
import {
  ERC20,
  LYTBaseWithRewards,
  PendleOwnershipToken,
  PendleYieldContractFactory,
  PendleYieldToken,
  PendleYTLYTBenqi,
} from '../../../../typechain-types';
import { deploy, getContractAt } from '../../../helpers';
import { TestEnv } from '../..';

export class BenqiYTLYT extends LytSingleReward<PendleYTLYTBenqi> {
  rawLyt: LYTBaseWithRewards = {} as LYTBaseWithRewards;
  yt: PendleYieldToken = {} as PendleYieldToken;
  ot: PendleOwnershipToken = {} as PendleOwnershipToken;

  constructor(lyt: PendleYTLYTBenqi) {
    super(lyt);
  }

  public async initialize(): Promise<void> {
    await super.initialize();
    this.yt = await getContractAt<PendleYieldToken>('PendleYieldToken', await this.lyt.yieldToken());
    this.ot = await getContractAt<PendleOwnershipToken>('PendleOwnershipToken', await this.yt.OT());
    this.rawLyt = await getContractAt<LYTBaseWithRewards>('LYTBaseWithRewards', await this.lyt.lyt());
    this.underlying = await getContractAt<ERC20>('ERC20', await this.rawLyt.address);
    this.yieldToken = await getContractAt<ERC20>('ERC20', await this.lyt.yieldToken());
  }

  async mintYieldToken(person: SignerWithAddress, amount: BigNumberish): Promise<void> {
    await this.rawLyt.connect(person).transfer(this.yt.address, amount);
    await this.yt.connect(person).mintYO(person.address, person.address);
  }
  async burnYieldToken(person: SignerWithAddress, amount: BN): Promise<void> {
    await this.yt.connect(person).transfer(this.yt.address, amount);
    await this.ot.connect(person).transfer(this.yt.address, amount);
    await this.yt.redeemYO(person.address);
  }
  async addFakeIncome(env: TestEnv): Promise<void> {
    // to be implemented
  }
  async yieldTokenBalance(addr: string): Promise<BN> {
    return await this.yt.balanceOf(addr);
  }

  async claimDirectReward(payer: SignerWithAddress, addr: string): Promise<void> {
    await this.yt.connect(payer).redeemDueRewards(addr);
  }

  async getDirectExchangeRate(): Promise<BN> {
    // to be implemented
    return BN.from(0);
  }
}

export interface YOEnv {
  factory: PendleYieldContractFactory;
  yt: PendleYieldToken;
  ot: PendleOwnershipToken;
  ytLyt: BenqiYTLYT;
  expiry: BN;
}

export async function deployYO(env: TestEnv): Promise<YOEnv> {
  /**** DEPLOY FACTORY ******/
  let divisor = env.mconsts.ONE_DAY;
  let expiry = BN.from(env.startTime).add(env.mconsts.SIX_MONTH);
  expiry = expiry.add(divisor.sub(expiry.mod(divisor)));
  const fee = BN.from(10).pow(15); // 0.1%
  const factory = await deploy<PendleYieldContractFactory>(env.deployer, 'PendleYieldContractFactory', [
    divisor,
    fee,
    env.treasury.address,
  ]);

  /**** DEPLOY YO ******/
  const lyt = env.qiLyt.lyt;
  await factory.createYieldContract(lyt.address, expiry);
  const yt = await getContractAt<PendleYieldToken>('PendleYieldToken', await factory.getYT(lyt.address, expiry));
  const ot = await getContractAt<PendleOwnershipToken>(
    'PendleOwnershipToken',
    await factory.getOT(lyt.address, expiry)
  );

  /**** DEPLOY YTLYT ******/
  const ytLytContract = await deploy<PendleYTLYTBenqi>(env.deployer, 'PendleYTLYTBenqi', [
    'YTLYT',
    'YTLYT',
    6,
    6,
    lyt.address,
    yt.address,
    await lyt.QI(),
    await lyt.WAVAX(),
  ]);

  const ytLyt = new BenqiYTLYT(ytLytContract);
  await ytLyt.initialize();

  await env.fundKeeper.mintYT(lyt.address, env.qiLyt.underlying.address, yt.address, env.mconsts.ONE_E_12);

  return {
    ot,
    yt,
    ytLyt,
    factory,
    expiry,
  };
}
