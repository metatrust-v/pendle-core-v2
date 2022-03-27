import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { AvaxConsts } from '@pendle/constants';
import { BigNumber as BN } from 'ethers';
import { ethers } from 'hardhat';
import { TestEnv } from '../environment';
import { getContractAt } from '.';
import { ERC20 } from '../../typechain-types';

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
