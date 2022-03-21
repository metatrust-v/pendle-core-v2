import { BigNumber as BN } from 'ethers';
import { Env } from '../..';
import {
  BenqiChainlinkOracle,
  Comptroller,
  ERC20Premined,
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

  // FUND REWARD
  const qiToken = await deploy<ERC20Premined>(env.deployer, 'ERC20Premined', ['Qi', 18]);
  await comptroller.setQiAddress(qiToken.address);
  await qiToken.transfer(comptroller.address, await qiToken.balanceOf(env.deployer.address));

  // DEPLOY TOKEN
  const interestRateModel = await deploy<JumpRateModel>(env.deployer, 'JumpRateModel', [
    BN.from(10).pow(16).mul(2),
    BN.from(10).pow(17),
    BN.from(10).pow(16).mul(109),
    BN.from(10).pow(17).mul(8),
  ]);

  const qiErc20Implementation = await deploy<QiErc20Delegate>(env.deployer, 'QiErc20Delegate', []);
  const qiUSD = await deploy<QiErc20Delegator>(env.deployer, 'QiErc20Delegator', [
    env.tokens.USD.address,
    comptroller.address,
    interestRateModel.address,
    BN.from(10).pow(18),
    'qiUSD',
    'qiUSD',
    8,
    env.deployer.address,
    qiErc20Implementation.address,
    '0x',
  ]);
  await approveAll(env, env.tokens.USD.address, qiUSD.address);

  // SET UP TOKEN
  await comptroller._supportMarket(qiUSD.address);
  const oracle = await deploy<BenqiChainlinkOracle>(env.deployer, 'BenqiChainlinkOracle', []);
  await oracle.setUnderlyingPrice(qiUSD.address, BN.from(10).pow(18));
  await comptroller._setPriceOracle(oracle.address);
  await comptroller._setCollateralFactor(qiUSD.address, BN.from(10).pow(18));
  await comptroller._setRewardSpeed(0, qiUSD.address, BN.from(10).pow(18));

  // FAKE AMOUNT
  const amount = BN.from(10).pow(18);
  await env.tokens.USD.transfer(env.protocolFakeUser.address, amount);
  await env.protocolFakeUser.depositBenqi(qiUSD.address, amount);

  return {
    qiUSDC: qiUSD as any as QiErc20,
  };
}
