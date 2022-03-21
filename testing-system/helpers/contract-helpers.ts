import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import { ERC20, IERC20 } from '../../typechain-types';
import { TestEnv } from '../environment';
import { getContractAt } from './hardhat-helpers';

export async function approveAll(env: TestEnv, tokenAddr: string, toAddr: string): Promise<void> {
  const tokenContract = await getContractAt<IERC20>('IERC20', tokenAddr);
  for (let person of env.wallets) {
    await tokenContract.connect(person).approve(toAddr, env.mconsts.INF);
  }
}

export async function clearFund(env: TestEnv, from: SignerWithAddress[], tokens: string[]): Promise<void> {
  for (let wallet of from) {
    for (let tokenAddr of tokens) {
      let token = await getContractAt<ERC20>('ERC20', tokenAddr);
      await token.connect(wallet).transfer(env.fundKeeper.address, await token.balanceOf(wallet.address));
    }
  }
}
