import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import hre from 'hardhat';
import { CommonFixture } from './fixtures/commonFixture';
import { loadFixture } from 'ethereum-waffle';
import {
  AvaxConsts,
  EthConsts,
  MiscConsts,
  MiscConstsType,
  PendleConstsType,
} from '@pendle/constants';
import {
  avalancheFixture,
  AvalancheFixture,
  EthereumFixture,
  ethereumFixture,
  LYTEnv,
} from './fixtures';
import { FundKeeper } from '../../typechain-types';
import { getLastBlockTimestamp } from '../helpers';
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
  network: Network;
  startTime: number;
}

export type TestEnv = BasicEnv & CommonFixture & AvalancheFixture & EthereumFixture & LYTEnv;

export async function loadBasicEnv(env: TestEnv) {
  env.wallets = await hre.ethers.getSigners();
  env.deployer = env.wallets[0];
  env.mconsts = MiscConsts;
  env.aconsts = AvaxConsts;
  env.econsts = EthConsts;
  env.startTime = await getLastBlockTimestamp();
}

export enum Network {
  ETH,
  AVAX,
}

export async function buildEnv(): Promise<TestEnv> {
  let env: TestEnv;
  switch (hre.network.config.chainId!) {
    case 1:
      env = await loadFixture(ethereumFixture);
      env.network = Network.ETH;
      break;
    case 43114:
      env = await loadFixture(avalancheFixture);
      env.network = Network.AVAX;
      break;
    default:
      throw new Error('Unsupported Network');
  }
  return env;
}
