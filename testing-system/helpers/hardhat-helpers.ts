import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Contract } from 'ethers';
import { assert } from 'chai';
import { BigNumber as BN } from 'ethers';
import hre, { ethers } from 'hardhat';

export async function deploy<CType extends Contract>(
  deployer: SignerWithAddress,
  abiType: string,
  args: any[],
  printLog: boolean = false
) {
  if (printLog) console.log(`Deploying ${abiType}...`);
  const contractFactory = await hre.ethers.getContractFactory(abiType);
  const contract = await contractFactory.connect(deployer).deploy(...args);
  await contract.deployed();
  if (printLog) console.log(`${abiType} deployed at address: ${(await contract).address}`);
  return contract as CType;
}

export async function getContractAt<CType extends Contract>(abiType: string, address: string) {
  return (await hre.ethers.getContractAt(abiType, address)) as CType;
}

export async function impersonateAccount(address: string) {
  await hre.network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [address],
  });
}

export async function impersonateAccountStop(address: string) {
  await hre.network.provider.request({
    method: 'hardhat_stopImpersonatingAccount',
    params: [address],
  });
}

export async function evm_snapshot() {
  return (await hre.network.provider.request({
    method: 'evm_snapshot',
    params: [],
  })) as string;
}

export async function evm_revert(snapshotId: string) {
  return (await hre.network.provider.request({
    method: 'evm_revert',
    params: [snapshotId],
  })) as string;
}

export async function advanceTime(duration: BN) {
  await hre.network.provider.send('evm_increaseTime', [duration.toNumber()]);
  await hre.network.provider.send('evm_mine', []);
}

export async function setTimeNextBlock(time: BN) {
  await hre.network.provider.send('evm_setNextBlockTimestamp', [time.toNumber()]);
}

export async function setTime(time: BN) {
  await hre.network.provider.send('evm_setNextBlockTimestamp', [time.toNumber()]);
  await hre.network.provider.send('evm_mine', []);
}

export async function advanceTimeAndBlock(time: BN, blockCount: number) {
  assert(blockCount >= 1);
  await advanceTime(time);
  await mineBlock(blockCount - 1);
}

export async function mineAllPendingTransactions() {
  let pendingBlock: any = await hre.network.provider.send('eth_getBlockByNumber', ['pending', false]);
  await mineBlock();
  pendingBlock = await hre.network.provider.send('eth_getBlockByNumber', ['pending', false]);
  assert(pendingBlock.transactions.length == 0);
}

export async function mineBlock(count?: number) {
  if (count == null) count = 1;
  while (count-- > 0) {
    await hre.network.provider.send('evm_mine', []);
  }
}

export async function minerStart() {
  await hre.network.provider.send('evm_setAutomine', [true]);
}

export async function minerStop() {
  await hre.network.provider.send('evm_setAutomine', [false]);
}

export async function getEth(user: string) {
  await hre.network.provider.send('hardhat_setBalance', [user, '0x56bc75e2d63100000000000000']);
}

export async function getLastBlockTimestamp() {
  const blockBefore = await hre.ethers.provider.getBlockNumber();
  const block = await hre.ethers.provider.getBlock(blockBefore);
  return block.timestamp;
}
