import { buildEnv, TestEnv, Mode } from './environment';

async function main() {
  const env: TestEnv = await buildEnv();
}

main();
