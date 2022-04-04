import { BigNumber as BN } from 'ethers';
import { TestEnv } from '..';
import { ERC20 } from '../../../typechain-types';
import { approveAll } from '../../helpers';
import { LytSingle } from '../lyt-testing-interfaces';
import { LYTSimpleInterface } from '../lyt-testing-interfaces/simple-interfaces';

export type LYTEnv = {
  underlying: ERC20;
  yieldToken: ERC20;
  REF_AMOUNT: BN;
  REF_AMOUNT_WEI: BN;
};

export async function parseLYTSingleEnv(
  env: TestEnv,
  lyt: LytSingle<LYTSimpleInterface>
): Promise<TestEnv> {
  env.underlying = lyt.underlying;
  env.yieldToken = lyt.yieldToken;
  env.REF_AMOUNT = BN.from(100);
  env.REF_AMOUNT_WEI = env.REF_AMOUNT.mul(BN.from(10).pow(await lyt.lyt.decimals()));
  await approveAll(env, lyt.underlying.address, lyt.address);
  await approveAll(env, lyt.underlying.address, lyt.yieldToken.address);
  await approveAll(env, lyt.yieldToken.address, lyt.address);
  return env;
}
