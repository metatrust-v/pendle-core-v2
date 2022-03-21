import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Env, loadBasicEnv } from '..';
import {
  ERC20,
  ERC20Premined,
  ERC20PresetFixedSupply,
  ERC20PresetFixedSupply__factory,
  ProtocolFakeUser,
} from '../../../typechain-types';
import { deploy } from '../../helpers';
export interface CommonTokens {
  USD: ERC20;
}

export type CommonFixture = {
  tokens: CommonTokens;
  protocolFakeUser: ProtocolFakeUser;
};

async function deployTokens(deployer: SignerWithAddress): Promise<CommonTokens> {
  console.log('Deploying test token...');
  return {
    USD: (await deploy<ERC20Premined>(deployer, 'ERC20Premined', ['USD', 6])) as any as ERC20,
  };
}

export async function commonFixture(): Promise<Env> {
  const env = {} as Env;
  await loadBasicEnv(env);
  return {
    ...env,
    tokens: await deployTokens(env.deployer),
    protocolFakeUser: await deploy<ProtocolFakeUser>(env.deployer, 'ProtocolFakeUser', []),
  };
}
