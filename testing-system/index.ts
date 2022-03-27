import { buildEnv, TestEnv, Mode } from './environment';

async function main() {
  const env: TestEnv = await buildEnv();

  console.log(await env.qiLyt.indexCurrent());
  await env.qiLyt.addFakeIncome(env);
  console.log(await env.qiLyt.indexCurrent());
}

main();
