import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { TestEnv } from '../..';
import { LytSingle } from '../../lyt-testing-interfaces';
import { ERC20, IREDACTEDStaking, IWXBTRFLY, PendleBtrflyLYT } from '../../../../typechain-types';
import {
  deploy,
  getContractAt,
  impersonateAccount,
  impersonateAccountStop,
  mineBlock,
  mintFromSource,
} from '../../../helpers';
import { BigNumber as BN } from 'ethers';
import { MiscConsts } from '@pendle/constants';
import hre from 'hardhat';

export class BtrflyLyt extends LytSingle<PendleBtrflyLYT> {
  BTRFLY: ERC20 = {} as ERC20;
  xBTRFLY: ERC20 = {} as ERC20;
  wxBTRFLY: IWXBTRFLY = {} as IWXBTRFLY;
  redactedStaking: IREDACTEDStaking = {} as IREDACTEDStaking;

  constructor(lyt: PendleBtrflyLYT, redactedStaking: IREDACTEDStaking) {
    super(lyt);
    this.redactedStaking = redactedStaking;
  }

  public async initialize(): Promise<void> {
    await super.initialize();

    this.BTRFLY = await getContractAt<ERC20>('ERC20', await this.lyt.BTRFLY());
    this.xBTRFLY = await getContractAt<ERC20>('ERC20', await this.lyt.xBTRFLY());
    this.wxBTRFLY = await getContractAt<IWXBTRFLY>('IWXBTRFLY', await this.lyt.wxBTRFLY());

    this.underlying = await getContractAt<ERC20>('ERC20', await this.lyt.BTRFLY());
    this.yieldToken = await getContractAt<ERC20>('ERC20', await this.lyt.wxBTRFLY());
  }
  /**
   * @param type 0 means from Btrfly, 1 means from xBtrfly
   */
  async mintYieldToken(person: SignerWithAddress, amount: BN, type: number = 0): Promise<void> {
    if (type == 0) {
      await this.wxBTRFLY.connect(person).wrapFromBTRFLY(amount);
    } else {
      await this.wxBTRFLY.connect(person).wrapFromxBTRFLY(amount);
    }
  }
  /**
   * @param type 0 means from Btrfly, 1 means from xBtrfly
   */
  async burnYieldToken(person: SignerWithAddress, amount: BN, type: number = 0): Promise<void> {
    if (type == 0) {
      await this.wxBTRFLY.connect(person).unwrapToBTRFLY(amount);
    } else {
      await this.wxBTRFLY.connect(person).unwrapToxBTRFLY(amount);
    }
  }
  async addFakeIncome(env: TestEnv): Promise<void> {
    await mineBlock((await this.redactedStaking.epoch())[0].toNumber());
    await this.redactedStaking.rebase();
  }
  async yieldTokenBalance(addr: string): Promise<BN> {
    return await this.wxBTRFLY.balanceOf(addr);
  }
  async getDirectExchangeRate(): Promise<BN> {
    return await this.wxBTRFLY.xBTRFLYValue(MiscConsts.ONE_E_18);
  }
}

export interface BtrflyEnv {
  btrflyLyt: BtrflyLyt;
}

export async function btrflySupport(env: TestEnv): Promise<BtrflyEnv> {
  const lyt = await deploy<PendleBtrflyLYT>(env.deployer, 'PendleBtrflyLYT', [
    'LYT-BTRFLY',
    'LYT-BTRFLY',
    18,
    9,
    env.econsts.tokens.BTRFLY!.address,
    env.econsts.tokens.xBTRFLY!.address,
    env.econsts.tokens.wxBTRFLY!.address,
  ]);
  const redactedStaking = await getContractAt<IREDACTEDStaking>(
    'IREDACTEDStaking',
    env.econsts.redacted!.BTRFLY_STAKING
  );
  const btrflyLyt: BtrflyLyt = new BtrflyLyt(lyt, redactedStaking);
  await btrflyLyt.initialize();

  await mintFromSource(env.fundKeeper.address, env.econsts.tokens.BTRFLY!, MiscConsts.INF);

  return {
    btrflyLyt,
  };
}
