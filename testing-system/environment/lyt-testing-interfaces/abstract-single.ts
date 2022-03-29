import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ERC20, IERC20, LYTBase, LYTBaseWithRewards } from '../../../typechain-types';
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

  public async initialize() {}

  abstract mintYieldToken(person: SignerWithAddress, amount: BN): Promise<void>;
  abstract burnYieldToken(person: SignerWithAddress, amount: BN): Promise<void>;
  abstract addFakeIncome(env: TestEnv): Promise<void>;
  abstract yieldTokenBalance(addr: string): Promise<BN>;
  abstract getDirectExchangeRate(): Promise<BN>;

  public async balanceOf(addr: string): Promise<BN> {
    return await this.lyt.balanceOf(addr);
  }

  public async assetBalanceOf(addr: string): Promise<BN> {
    return await this.lyt.callStatic.assetBalanceOf(addr);
  }

  public async indexCurrent(): Promise<BN> {
    return await this.lyt.callStatic.lytIndexCurrent();
  }

  // Will change these when routers are finallized
  public async mint(
    payer: SignerWithAddress,
    recipient: string,
    tokenIn: string,
    tokenAmount: BigNumberish,
    minAmountLytOut: BigNumberish = 0
  ): Promise<BN> {
    await (tokenIn == this.underlying.address ? this.underlying : this.yieldToken)
      .connect(payer)
      .transfer(this.lyt.address, tokenAmount);
    let preBal = await this.balanceOf(recipient);
    await this.lyt.connect(payer).mint(recipient, tokenIn, minAmountLytOut);
    return (await this.balanceOf(recipient)).sub(preBal);
  }

  public async redeem(
    payer: SignerWithAddress,
    recipient: string,
    tokenOut: string,
    lytAmount: BigNumberish,
    amountBaseOut: BigNumberish = 0
  ): Promise<BN> {
    await this.lyt.connect(payer).transfer(this.lyt.address, lytAmount);
    let baseToken = await getContractAt<ERC20>('ERC20', tokenOut);
    let preBal = await baseToken.balanceOf(recipient);
    await this.lyt.connect(payer).redeem(recipient, tokenOut, amountBaseOut);
    return (await baseToken.balanceOf(recipient)).sub(preBal);
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

  abstract claimDirectReward(payer: SignerWithAddress, person: string): Promise<void>;

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
