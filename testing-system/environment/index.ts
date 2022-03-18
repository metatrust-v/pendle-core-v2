import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import hre from 'hardhat';
import { ethers, waffle } from 'hardhat';
import { commonFixture, CommonFixture } from './fixtures/commonFixture';
import { loadFixture } from 'ethereum-waffle';
import { MiscConsts, MiscConstsType } from '@pendle/constants';
import { avalancheFixture, AvalancheFixture } from './fixtures';

export enum Mode {
  BENQI,
  YEARN,
  BTRFLY,
}

export interface BasicEnv {
  wallets: SignerWithAddress[];
  deployer: SignerWithAddress;
  mconsts: MiscConstsType;
}

export type Env = BasicEnv & CommonFixture & AvalancheFixture;

export async function loadBasicEnv(env: Env) {
  env.wallets = await hre.ethers.getSigners();
  env.deployer = env.wallets[0];
  env.mconsts = MiscConsts;
}

export async function buildEnv(): Promise<Env> {
  switch (hre.network.config.chainId!) {
    case 43114:
      return await loadFixture(avalancheFixture);
    default:
      throw new Error('Unsupported Network');
  }
}
