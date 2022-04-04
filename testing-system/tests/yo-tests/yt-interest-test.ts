import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber as BN } from 'ethers';
import { ERC20 } from '../../../typechain-types';
import { buildEnv, TestEnv } from '../../environment';
import { parseLYTSingleEnv } from '../../environment/fixtures';
import { BenqiLyt } from '../../environment/fixtures/avalanche/deployBenqi';
import { BenqiYTLYT } from '../../environment/fixtures/avalanche/deployYieldToken';
import {
  advanceTime,
  approxBigNumber,
  approxByPercent,
  clearFund,
  evm_revert,
  evm_snapshot,
  fundToken,
  getLastBlockTimestamp,
  getSumBalance,
  minBN,
  minBNs,
  random,
  setTimeNextBlock,
} from '../../helpers';
import { runTest as runLYTRewardTest } from '../lyt-tests/reward-test';

describe('YT Reward tests', async () => {
  let env: TestEnv;
  let lyt: BenqiYTLYT;
  let qiLyt: BenqiLyt;

  let globalSnapshotId: string;
  let snapshotId: string;
  let wallets: SignerWithAddress[];
  let REF_AMOUNT_WEI: BN;

  let underlying: ERC20;
  let yieldToken: ERC20;

  before(async () => {
    env = await buildEnv();
    globalSnapshotId = await evm_snapshot();
    snapshotId = await evm_snapshot();
    wallets = env.wallets;
    lyt = env.ytLyt;
    qiLyt = env.qiLyt;
  });

  beforeEach(async () => {
    await evm_revert(snapshotId);
    snapshotId = await evm_snapshot();
    await parseLYTSingleEnv(env, qiLyt);
    env = await parseLYTSingleEnv(env, lyt);
    ({ underlying, yieldToken, REF_AMOUNT_WEI } = env);
    await clearFund(env, wallets, [underlying.address, yieldToken.address]);
  });

  after(async () => {
    await evm_revert(globalSnapshotId);
  });

  it('YT & OT Holders should receive the same amount of interest', async() => {

  });

  it('OT holders should be able to redeem their underlying after expiry', async() => {
    for(let i = 0; i < wallets.length; ++i) {
        const person = wallets[i];
        const amount = REF_AMOUNT_WEI.mul(2**i);
        await fundToken(env, [person.address], qiLyt.underlying.address, amount);
        await qiLyt.mint(person, person.address, qiLyt.underlying.address, amount);
    }
    await setTimeNextBlock(env.expiry.add(env.startTime).div(2));

    for(let i = 0; i < wallets.length; ++i) {
        const person = wallets[i];
        await env.yt.redeem
    }
  });
});
