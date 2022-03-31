import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { AvaxConsts, Erc20Token, MiscConsts } from '@pendle/constants';
import { BigNumber as BN } from 'ethers';
import { ethers } from 'hardhat';
import { TestEnv } from '../environment';
import { getContractAt } from '.';
import { ERC20 } from '../../typechain-types';
import { getEth, impersonateAccount, impersonateAccountStop } from './hardhat-helpers';
import { assert } from 'console';
import hre from 'hardhat';

export async function getBalance(token: any, users: string[]): Promise<BN[]> {
  if (typeof token == 'string') {
    token = await getContractAt<ERC20>('ERC20', token);
  }
  const bals: BN[] = [];
  for (const user of users) {
    if (token.address != AvaxConsts.tokens.NATIVE.address) {
      bals.push((await token.balanceOf(user)) as BN);
    } else {
      bals.push(await ethers.provider.getBalance(user));
    }
  }
  return bals;
}

export async function mintFromSource(person: string, token: Erc20Token, amount: BN): Promise<void> {
  let source = token.whale!;
  await getEth(source);
  await impersonateAccount(source);
  const signer = await hre.ethers.getSigner(source);
  const contractToken = await getContractAt<ERC20>('ERC20', token.address);
  let balanceOfSource: BN = await contractToken.balanceOf(source);
  if (amount == MiscConsts.INF) amount = balanceOfSource;
  assert(amount.lte(balanceOfSource), `Total amount of ${token.symbol!} minted exceeds limit`);
  await contractToken.connect(signer).transfer(person, amount);
  await impersonateAccountStop(source);
}
