import { BigNumber as BN, BigNumberish, CallOverrides, ContractTransaction, Overrides, Signer } from 'ethers';
import { Provider } from '@ethersproject/abstract-provider';

export interface LYTSimpleInterface {
  connect(signerOrProvider: Signer | Provider | string): this;

  yieldToken(overrides?: CallOverrides): Promise<string>;
  getBaseTokens(overrides?: CallOverrides): Promise<string[]>;

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

export interface LYTRewardSimpleInterface extends LYTSimpleInterface {
  redeemReward(user: string, overrides?: Overrides & { from?: string | Promise<string> }): Promise<ContractTransaction>;
  getRewardTokens(overrides?: CallOverrides): Promise<string[]>;
}
