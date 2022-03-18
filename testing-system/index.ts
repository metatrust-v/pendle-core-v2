import { buildEnv, Env, Mode } from './environment';

async function main() {
  const env: Env = await buildEnv();
  const env2: Env = await buildEnv();
}

main();
