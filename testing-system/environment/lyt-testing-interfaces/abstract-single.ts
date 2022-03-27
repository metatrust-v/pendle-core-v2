import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ERC20, IERC20, LYTWrap, LYTWrapWithRewards } from '../../../typechain-types';
import { BigNumber as BN, BigNumberish, CallOverrides, ContractTransaction, Overrides, Signer } from 'ethers';
import { Provider } from '@ethersproject/abstract-provider';
import { getContractAt } from '../../helpers';
import assert from 'assert';
import { TestEnv } from '..';
import { LYTSimpleInterface, LYTRewardSimpleInterface } from './simple-interfaces';

export abstract class LytSingle<LYT extends LYTSimpleInterface> {
  lyt: LYT;
  underlying: ERC20 = {} as ERC20;
  yieldToken: ERC20 = {} as ERC20;

  constructor(lyt: LYT) {
    this.lyt = lyt;
  }

  public async initialize() {
    this.yieldToken = await getContractAt<ERC20>('ERC20', await this.lyt.yieldToken());
    const baseTokens = await this.lyt.getBaseTokens();
    assert(baseTokens.length == 1, 'Number of basetokens not 1');
    this.underlying = await getContractAt<ERC20>('ERC20', baseTokens[0]);
  }

  abstract mintYieldToken(person: SignerWithAddress, amount: BN): Promise<void>;
  abstract burnYieldToken(person: SignerWithAddress, amount: BN): Promise<void>;
  abstract addFakeIncome(env: TestEnv): Promise<void>;
  abstract yieldTokenBalance(addr: string): Promise<BN>;

  public async balanceOf(addr: string): Promise<BN> {
    return await this.lyt.balanceOf(addr);
  }

  public async assetBalanceOf(addr: string): Promise<BN> {
    return await this.lyt.callStatic.assetBalanceOf(addr);
  }

  public async indexCurrent(): Promise<BN> {
    return await this.lyt.callStatic.lytIndexCurrent();
  }
  public async depositBaseToken(
    person: SignerWithAddress,
    baseToken: string,
    amount: BigNumberish,
    minAmountLytOut: BigNumberish = 0
  ): Promise<BN> {
    const result = await this.lyt
      .connect(person)
      .callStatic.depositBaseToken(person.address, baseToken, amount, minAmountLytOut);
    await this.lyt.connect(person).depositBaseToken(person.address, baseToken, amount, minAmountLytOut);
    return result;
  }
  public async depositBaseTokenFor(
    person: SignerWithAddress,
    to: string,
    baseToken: string,
    amount: BigNumberish,
    minAmountLytOut: BigNumberish = 0
  ): Promise<BN> {
    const result = await this.lyt.connect(person).callStatic.depositBaseToken(to, baseToken, amount, minAmountLytOut);
    await this.lyt.connect(person).depositBaseToken(to, baseToken, amount, minAmountLytOut);
    return result;
  }
  public async redeemBaseToken(
    person: SignerWithAddress,
    baseToken: string,
    amount: BigNumberish,
    minAmountBaseOut: BigNumberish = 0
  ): Promise<BN> {
    const result = await this.lyt
      .connect(person)
      .callStatic.redeemToBaseToken(person.address, amount, baseToken, minAmountBaseOut);
    await this.lyt.connect(person).redeemToBaseToken(person.address, amount, baseToken, minAmountBaseOut);
    return result;
  }
  public async redeemBaseTokenFor(
    person: SignerWithAddress,
    to: string,
    baseToken: string,
    amount: BigNumberish,
    minAmountBaseOut: BigNumberish = 0
  ): Promise<BN> {
    const result = await this.lyt.connect(person).callStatic.redeemToBaseToken(to, amount, baseToken, minAmountBaseOut);
    await this.lyt.connect(person).redeemToBaseToken(to, amount, baseToken, minAmountBaseOut);
    return result;
  }
  public async depositYieldToken(
    person: SignerWithAddress,
    amount: BigNumberish,
    minAmountLytOut: BigNumberish = 0
  ): Promise<BN> {
    const result = await this.lyt.connect(person).callStatic.depositYieldToken(person.address, amount, 0);
    await this.lyt.connect(person).depositYieldToken(person.address, amount, minAmountLytOut);
    return result;
  }
  public async depositYieldTokenFor(
    person: SignerWithAddress,
    to: string,
    amount: BigNumberish,
    minAmountLytOut: BigNumberish = 0
  ): Promise<BN> {
    const result = await this.lyt.connect(person).callStatic.depositYieldToken(to, amount, 0);
    await this.lyt.connect(person).depositYieldToken(to, amount, minAmountLytOut);
    return result;
  }
  public async redeemYieldToken(
    person: SignerWithAddress,
    amountLyt: BigNumberish,
    minAmountYieldOut: BigNumberish = 0
  ): Promise<BN> {
    const result = await this.lyt
      .connect(person)
      .callStatic.redeemToYieldToken(person.address, amountLyt, minAmountYieldOut);
    await this.lyt.connect(person).redeemToYieldToken(person.address, amountLyt, minAmountYieldOut);
    return result;
  }
  public async redeemYieldTokenFor(
    person: SignerWithAddress,
    to: string,
    amountLyt: BigNumberish,
    minAmountYieldOut: BigNumberish = 0
  ): Promise<BN> {
    const result = await this.lyt.connect(person).callStatic.redeemToYieldToken(to, amountLyt, minAmountYieldOut);
    await this.lyt.connect(person).redeemToYieldToken(to, amountLyt, minAmountYieldOut);
    return result;
  }
  public async transfer(from: SignerWithAddress, to: string, amount: BigNumberish): Promise<void> {
    await this.lyt.connect(from).transfer(to, amount);
  }
  public async approve(from: SignerWithAddress, to: string, amount: BigNumberish): Promise<void> {
    await this.lyt.connect(from).approve(to, amount);
  }
}

export abstract class LytSingleReward<LYT extends LYTRewardSimpleInterface> extends LytSingle<LYT> {
  rewardTokens: ERC20[] = [];

  abstract claimDirectReward(payer: SignerWithAddress, person: SignerWithAddress): Promise<void>;

  public async initialize(): Promise<void> {
    await super.initialize();
    const rewardTokenAddr: string[] = await this.lyt.getRewardTokens();
    assert(rewardTokenAddr.length > 0, 'LYT does not have reward');
    for (let tokenAddr of rewardTokenAddr) {
      this.rewardTokens.push(await getContractAt<ERC20>('ERC20', tokenAddr));
    }
  }

  public async redeemReward(payer: SignerWithAddress, addr: string): Promise<void> {
    await this.lyt.connect(payer).redeemReward(addr);
  }

  public async rewardBalance(addr: string, rwdToken: number = 0): Promise<BN> {
    return await this.rewardTokens[rwdToken].balanceOf(addr);
  }
}
