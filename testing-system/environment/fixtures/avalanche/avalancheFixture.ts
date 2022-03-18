import { commonFixture } from '..';
import { loadFixture } from 'ethereum-waffle';
import { IJoePair, IJoeRouter01, IQiErc20 } from '../../../../typechain-types';
import { BenqiEnv, deployBenqi } from './deployBenqi';
import { Env } from '../..';

export type AvalancheFixture = BenqiEnv;

export async function avalancheFixture(): Promise<Env> {
  const env = await loadFixture(commonFixture);
  return {
    ...env,
    ...(await deployBenqi(env)),
  };
}
