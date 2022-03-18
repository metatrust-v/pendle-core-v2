import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Contract } from 'ethers';
import hre from 'hardhat';

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
