import { BigNumber as BN } from 'ethers';
import { Env } from '../..';
import {
  Comptroller,
  JumpRateModel,
  QiErc20,
  QiErc20Delegate,
  QiErc20Delegator,
  Unitroller,
} from '../../../../typechain-types';
import { approveAll, deploy, getContractAt } from '../../../helpers';

export interface BenqiEnv {
  qiUSDC: QiErc20;
}

export async function deployBenqi(env: Env): Promise<BenqiEnv> {
  const comptrollerImplementation = await deploy<Comptroller>(env.deployer, 'Comptroller', []);
  const unitroller = await deploy<Unitroller>(env.deployer, 'Unitroller', []);
  await unitroller._setPendingImplementation(comptrollerImplementation.address);
  await comptrollerImplementation._become(unitroller.address);

  const comptroller = await getContractAt<Comptroller>('Comptroller', unitroller.address);

  const interestRateModel = await deploy<JumpRateModel>(env.deployer, 'JumpRateModel', [
    BN.from(10).pow(16).mul(2),
    BN.from(10).pow(17),
    BN.from(10).pow(16).mul(109),
    BN.from(10).pow(17).mul(8),
  ]);

  const qiErc20Implementation = await deploy<QiErc20Delegate>(env.deployer, 'QiErc20Delegate', []);

  const qiUSDC = await deploy<QiErc20Delegator>(env.deployer, 'QiErc20Delegator', [
    env.tokens.USDC.address,
    comptroller.address,
    interestRateModel.address,
    BN.from(10).pow(18),
    'qiUSDC',
    'qiUSDC',
    8,
    env.deployer.address,
    qiErc20Implementation.address,
    '0x',
  ]);
  await approveAll(env, env.tokens.USDC.address, qiUSDC.address);
  return {
    qiUSDC: qiUSDC as any as QiErc20,
  };
}
