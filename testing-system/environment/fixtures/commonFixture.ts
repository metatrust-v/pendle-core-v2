import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber as BN } from 'ethers';
import { TestEnv, loadBasicEnv } from '..';
import { ERC20, ERC20Premined, FundKeeper } from '../../../typechain-types';
import { clearFund, deploy, getEth } from '../../helpers';
export interface CommonTokens {
  USD: ERC20;
}

export type CommonFixture = {
  tokens: CommonTokens;
  fundKeeper: FundKeeper;
  treasury: FundKeeper;
};

async function deployTokens(deployer: SignerWithAddress): Promise<CommonTokens> {
  console.log('Deploying test token...');
  return {
    USD: (await deploy<ERC20Premined>(deployer, 'ERC20Premined', ['USD', 6])) as any as ERC20,
  };
}

export async function commonFixture(): Promise<TestEnv> {
  const env = {} as TestEnv;
  await loadBasicEnv(env);

  env.fundKeeper = await deploy<FundKeeper>(env.deployer, 'FundKeeper', []);
  env.treasury = await deploy<FundKeeper>(env.deployer, 'FundKeeper', []);

  await getEth(env.fundKeeper.address);
  env.tokens = await deployTokens(env.deployer);
  await clearFund(env, [env.deployer], [env.tokens.USD.address]);
  return env;
}
