import { ethers } from "hardhat";
import { ERC20, IRainbowBridge } from "../typechain-types";
import { Blob } from 'buffer';
import ExportToCSV from "@molteni/export-csv"; 


const START_BLOCK = 12044301;
const LATEST_BLOCK = 14427092;
// const LATEST_BLOCK = 12094510;

const DELTA = 86400 * 20 / 15;


type User = {
  address: string;
  transaction: string;
}

async function main() {
  const USDT = '0x4988a896b1227218e4A686fdE5EabdcAbd91571f'
  const USDTContract =  await ethers.getContractAt('ERC20', USDT) as ERC20;
  let filter = USDTContract.filters.Transfer()

//   console.log(await USDTContract.queryFilter(filter, 61907653 - DELTA, 61907653));

  let m: Map<string,number> = new Map<string, number>()

  const events = await USDTContract.queryFilter(filter, 61907653 - DELTA, 61907653);
  for(let e of events) {
    let addr = e.args.from;
    if (!m.has(addr)) m.set(addr, 0);
    m.set(addr, m.get(addr)!+1);
  }

  let m2= new Map([...m.entries()].sort((a,b) => b[1] - a[1]))
  m2.forEach((v, k) => {
      console.log(k, v);
  })

//   for(let i = START_BLOCK; i <= LATEST_BLOCK; i += DELTA) {
//     console.log("Doing: ", i);
//     let events = await rb.queryFilter(filter, i, Math.min(i+DELTA-1, LATEST_BLOCK));
//     for(let e of events) {
//       m.set(e.args.accountId, e.transactionHash);
//     }
//   }

//   const data: User[] = [];
//   m.forEach((v, k) => {
//     console.log(k, v);
//   });
}

main();