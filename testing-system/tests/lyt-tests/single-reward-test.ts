import { buildEnv } from '../../environment';
import { runTest } from './reward-test';

it('Run reward tests', async () => {
  const env = await buildEnv();
  await runTest(env, env.qiLyt);
});
