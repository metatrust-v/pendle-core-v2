import { buildEnv, TestEnv } from "../../environment";
import {runTest as runRewardTest} from "../lyt-tests/reward-test";


describe('YT Reward tests', async() => {
    let env: TestEnv;

    before(async() => {
        env = await buildEnv();
    });

    it('Run regular LYT reward test', async() => {
        await runRewardTest(env, env.ytLyt); 
    });
});