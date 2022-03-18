import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Env, loadBasicEnv } from '..';
import {
  ERC20,
  ERC20Premined,
  ERC20PresetFixedSupply,
  ERC20PresetFixedSupply__factory,
} from '../../../typechain-types';
import { deploy } from '../../helpers';
export interface CommonTokens {
  USDC: ERC20;
  USDT: ERC20;
  DAI: ERC20;
  NEAR: ERC20;
  WBTC: ERC20;
}

export type CommonFixture = {
  tokens: CommonTokens;
};

async function deployTokens(deployer: SignerWithAddress): Promise<CommonTokens> {
  console.log('Deploying 5 test tokens...');
  return {
    USDC: (await deploy<ERC20Premined>(deployer, 'ERC20Premined', ['USDC', 6])) as any as ERC20,
    USDT: (await deploy<ERC20Premined>(deployer, 'ERC20Premined', ['USDT', 8])) as any as ERC20,
    DAI: (await deploy<ERC20Premined>(deployer, 'ERC20Premined', ['DAI', 18])) as any as ERC20,
    WBTC: (await deploy<ERC20Premined>(deployer, 'ERC20Premined', ['WBTC', 8])) as any as ERC20,
    NEAR: (await deploy<ERC20Premined>(deployer, 'ERC20Premined', ['NEAR', 24])) as any as ERC20,
  };
}

export async function commonFixture(): Promise<Env> {
  const env = {} as Env;
  await loadBasicEnv(env);
  return {
    ...env,
    tokens: await deployTokens(env.deployer),
  };
}
