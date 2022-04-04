import {
  BigNumber as BN,
  BigNumberish,
  CallOverrides,
  ContractTransaction,
  Overrides,
  Signer,
} from 'ethers';
import { Provider } from '@ethersproject/abstract-provider';

export interface LYTSimpleInterface {
  address: string;

  connect(signerOrProvider: Signer | Provider | string): this;

  decimals(overrides?: CallOverrides): Promise<number>;
  assetDecimals(overrides?: CallOverrides): Promise<number>;
  getBaseTokens(overrides?: CallOverrides): Promise<string[]>;

  mint(
    recipient: string,
    baseTokenIn: string,
    minAmountLytOut: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  redeem(
    recipient: string,
    baseTokenOut: string,
    minAmountBaseOut: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  balanceOf(account: string, overrides?: CallOverrides): Promise<BN>;
  transfer(
    to: string,
    amount: BigNumberish,
    overrides?: CallOverrides
  ): Promise<ContractTransaction>;
  approve(
    spender: string,
    amount: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  lytIndexCurrent(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;
  lytIndexStored(overrides?: CallOverrides): Promise<BN>;
  isValidBaseToken(token: string, overrides?: CallOverrides): Promise<boolean>;

  callStatic: {
    lytIndexCurrent(overrides?: Overrides & { from?: string | Promise<string> }): Promise<BN>;
  };
}

export interface LYTRewardSimpleInterface extends LYTSimpleInterface {
  redeemReward(
    user: string,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;
  getRewardTokens(overrides?: CallOverrides): Promise<string[]>;
}
