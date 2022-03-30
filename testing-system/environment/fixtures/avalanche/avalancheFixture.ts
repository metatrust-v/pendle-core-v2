import { commonFixture } from '..';
import { loadFixture } from 'ethereum-waffle';
import { IJoePair, IJoeRouter01, IQiErc20 } from '../../../../typechain-types';
import { BenqiEnv, deployBenqi } from './deployBenqi';
import { YOEnv, deployYO } from './deployYieldToken';
import { TestEnv } from '../..';

export type AvalancheFixture = BenqiEnv & YOEnv;

export async function avalancheFixture(): Promise<TestEnv> {
  let env = await loadFixture(commonFixture);
  env = {
    ...env,
    ...(await deployBenqi(env)),
  };

  env = {
    ...env,
    ...(await deployYO(env)),
  };
  return env;
}
