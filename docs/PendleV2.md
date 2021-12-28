# Pendle V2

## Overview
* PendleV2 is a complete and standalone smart contract system for tokenising and trading the yield of yield generating mechanisms in DeFi
* PendleV2 consists of 5 relatively independent components:
    * Liquid reward token (LYT), a.k.a ERC4000: a standard for any mechanism that generates yield in DeFi
    * LYT Depository: a system to hold LYTs for any protocols that want to work with LYTs
    * Yield Splitter: a protocol for splitting a LYT into yield tokens (YTs) and Ownership Tokens (OTs)
    * Yield Market: a system to enable efficient yield trading through trading OTs and YTs with any token with relatively low slippage
    * Pendle Governance: a system to
      * Incentivise liquidity providers for PendleV2 Yield Trading
      * Give utility to the PENDLE token through incentive boosting and voting on incentive allocation
* Although the last 3 components (PendleV2 Yield Splitter, PendleV2 yield Trading and Pendle Governance) are specific to yield trading and other applications on top of yield trading, LYT and LYT Depository are at the general infrastructure level for DeFi that could have a wide range of other applications.
  
## 1. LYT
* A LYT is a yield bearing token that constantly accrues yield to its holder
* Any mechanism that generates yield can be made into a LYT, including
  * Lending position in a money market (cToken, aToken)
  * Farming position in a vault (Yearn, Harvest, Ribbon)
  * Liquidity provision position in an AMM (UniswapV2, UniswapV3, Curve, KyberDMM)
  * Staking position in a rebasing currency (Ohm, Wonderland)
  * Liquid staking position (Lido)
  * Liquidity farming position (Sushi Onsen, protocols' pool2)
* With a standard behaviour, LYT can be easily integrated into any other protocols or products that work with a yield bearing token.
* [Detailed specs](./LYT.md)

## 2. LYT Depository
* Holds LYTs for anyone who wants to keep a LYT balance
* Allows users to flashloan LYTs
* Will be used by PendleV2 Yield Splitter and PendleV2 Yield Market
* [Detailed specs](./LYTDepository.md)
  
## 3. Yield Splitter
* Any LYT can be splitted into YTs and OTs, with respect to an expiry
* YTs get all the yield from the LYT until the expiry
* OTs have the right the redeem the initial capital after the expiry
* [Detailed specs](./YieldSplitter.md)

## 4. Yield Market
* There are 4 components in PendleV2's Reward Market:
  * OT AMM: An AMM that enables efficient trading between a LYT and its corresponding OT
  * YT Pseudo-AMM: A system to enable trading between a LYT and its corresponding YT, while ultilising the OT AMM behind the scene
  * LYT Trading Router: A routing system to trade a LYT with any other token, through other AMMs
  * Yield Market Router: The user facing router to trade OT/YT against any other tokens, with support for advanced order types like limit orders
* [Detailed specs](./YieldMarket.md)

## 5. Pendle Governance
* Follows a similar mechanism to veCRV, PENDLE tokens could be locked up for up to 4 years to mint xPENDLE
* xPENDLE can be used to boost one's liquidity incentives in all of PendleV2's OT pools
* xPENDLE can also be used to vote for the allocation of PENDLE incentives to the different pools
* xPENDLE staking gives holder a portion of PENDLE's fees ?
* [Detailed specs](./PendleGovernance.md)