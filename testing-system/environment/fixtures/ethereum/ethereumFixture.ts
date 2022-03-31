import { commonFixture } from '..';
import { loadFixture } from 'ethereum-waffle';
import { BtrflyEnv, btrflySupport } from './btrflySupport';
import { TestEnv } from '../..';

export type EthereumFixture = BtrflyEnv;

export async function ethereumFixture(): Promise<TestEnv> {
  const env = await loadFixture(commonFixture);
  return {
    ...env,
    ...(await btrflySupport(env)),
  };
}
