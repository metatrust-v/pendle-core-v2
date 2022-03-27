import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import hre from 'hardhat';
import { CommonFixture } from './fixtures/commonFixture';
import { loadFixture } from 'ethereum-waffle';
import { AvaxConsts, EthConsts, MiscConsts, MiscConstsType, PendleConstsType } from '@pendle/constants';
import { avalancheFixture, AvalancheFixture } from './fixtures';
import { FundKeeper } from '../../typechain-types';
export * from './lyt-testing-interfaces/abstract-single';

export enum Mode {
  BENQI,
  YEARN,
  BTRFLY,
}

export interface BasicEnv {
  wallets: SignerWithAddress[];
  deployer: SignerWithAddress;
  fundKeeper: FundKeeper;
  mconsts: MiscConstsType;
  aconsts: PendleConstsType;
  econsts: PendleConstsType;
}

export type TestEnv = BasicEnv & CommonFixture & AvalancheFixture;

export async function loadBasicEnv(env: TestEnv) {
  env.wallets = await hre.ethers.getSigners();
  env.deployer = env.wallets[0];
  env.mconsts = MiscConsts;
  env.aconsts = AvaxConsts;
  env.econsts = EthConsts;
}

export async function buildEnv(): Promise<TestEnv> {
  switch (hre.network.config.chainId!) {
    case 43114:
      return await loadFixture(avalancheFixture);
    default:
      throw new Error('Unsupported Network');
  }
}
