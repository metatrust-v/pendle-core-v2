import { ethers } from 'hardhat';
import { ERC20, IERC20 } from '../../typechain-types';
import { Env } from '../environment';
import { getContractAt } from './hardhat-helpers';

export async function approveAll(env: Env, tokenAddr: string, toAddr: string): Promise<void> {
  const tokenContract = await getContractAt<IERC20>('IERC20', tokenAddr);
  for (let person of env.wallets) {
    await tokenContract.connect(person).approve(toAddr, env.mconsts.INF);
  }
}
