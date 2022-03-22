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
  public async depositYieldToken(person: SignerWithAddress, amount: BigNumberish): Promise<void> {
    await this.lyt.connect(person).depositYieldToken(person.address, amount, 0);
  }
  public async redeemYieldToken(person: SignerWithAddress, amountLyt: BigNumberish): Promise<void> {
    await this.lyt.connect(person).redeemToYieldToken(person.address, amountLyt, 0);
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

  public async redeemReward(addr: string): Promise<void> {
    await this.lyt.redeemReward(addr);
  }

  public async rewardBalance(addr: string, rwdToken: number = 0): Promise<BN> {
    return await this.rewardTokens[rwdToken].balanceOf(addr);
  }
}