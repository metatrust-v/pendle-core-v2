import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ERC20, IERC20, LYTWrap, LYTWrapWithRewards } from '../../typechain-types';
import { BigNumber as BN, BigNumberish, CallOverrides, ContractTransaction, Overrides, Signer } from 'ethers';
import { Provider } from '@ethersproject/abstract-provider';
import { getContractAt } from '../helpers';
import assert from 'assert';
import { TestEnv } from '.';

interface LYTSimpleInterface {
  connect(signerOrProvider: Signer | Provider | string): this;

  yieldToken(overrides?: CallOverrides): Promise<string>;

  depositBaseToken(
    recipient: string,
    baseTokenIn: string,
    amountBaseIn: BigNumberish,
    minAmountLytOut: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  redeemToBaseToken(
    recipient: string,
    amountLytRedeem: BigNumberish,
    baseTokenOut: string,
    minAmountBaseOut: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  depositYieldToken(
    recipient: string,
    amountYieldIn: BigNumberish,
    minAmountLytOut: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  redeemToYieldToken(
    recipient: string,
    amountLytRedeem: BigNumberish,
    minAmountYieldOut: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;
  balanceOf(account: string, overrides?: CallOverrides): Promise<BN>;
  transfer(to: string, amount: BigNumberish, overrides?: CallOverrides): Promise<ContractTransaction>;
  approve(
    spender: string,
    amount: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  callStatic: {
    depositBaseToken(
      recipient: string,
      baseTokenIn: string,
      amountBaseIn: BigNumberish,
      minAmountLytOut: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BN>;
    redeemToBaseToken(
      recipient: string,
      amountLytRedeem: BigNumberish,
      baseTokenOut: string,
      minAmountBaseOut: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BN>;
    depositYieldToken(
      recipient: string,
      amountYieldIn: BigNumberish,
      minAmountLytOut: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BN>;
    redeemToYieldToken(
      recipient: string,
      amountLytRedeem: BigNumberish,
      minAmountYieldOut: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BN>;
    lytIndexCurrent(overrides?: Overrides & { from?: string | Promise<string> }): Promise<BN>;
    assetBalanceOf(user: string, overrides?: CallOverrides): Promise<BN>;
  };
}

interface LYTRewardSimpleInterface extends LYTSimpleInterface {
  redeemReward(user: string, overrides?: Overrides & { from?: string | Promise<string> }): Promise<ContractTransaction>;
  getRewardTokens(overrides?: CallOverrides): Promise<string[]>;
}

export abstract class LytTesting<LYT extends LYTSimpleInterface> {
  lyt: LYT;

  constructor(lyt: LYT) {
    this.lyt = lyt;
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

export abstract class LytRewardTesting<LYT extends LYTRewardSimpleInterface> extends LytTesting<LYT> {
  rewardTokens: IERC20[] = [];
  public async initialize(): Promise<void> {
    const rewardTokenAddr: string[] = await this.lyt.getRewardTokens();
    assert(rewardTokenAddr.length > 0, 'LYT does not have reward');
    for (let tokenAddr of rewardTokenAddr) {
      this.rewardTokens.push(await getContractAt<IERC20>('IERC20', tokenAddr));
    }
  }

  public async redeemReward(payer: SignerWithAddress, addr: string): Promise<void> {
    await this.lyt.connect(payer).redeemReward(addr);
  }

  public async rewardBalance(addr: string, rwdToken: number = 0): Promise<BN> {
    return await this.rewardTokens[rwdToken].balanceOf(addr);
  }
}
