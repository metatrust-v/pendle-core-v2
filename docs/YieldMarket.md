# Yield Market
[Back](PendleV2.md)

### OT AMM
* [Link to details](OT_AMM.md)

### YT Pseudo-AMM
* This is a routing mechanism to let users trade YT against it's own LYT
1. Swap exact `YIn` YT to LYT:
   * Flashloan some LYT
   * swap exactly `YIn` OT out using the OT AMM
   * Redeem YT + OT to get LYT
   * Repays flashloan
2. Swap YT to get exact `L` LYT?
   * Flashloan a bunch of LYT
   * Calculate how much `yIn` YT to use to get exactly `L` LYT in the end
     * TODO: Solve equations for `yIn`
   * Follow the same steps as 1
3. Swap LYT to exact `YOut` YT
   * Flashloan a bunch of LYT
   * Tokenise LYT to get exactly `YOut` YT and `YOut` OT
   * Swap exact `YOut` OT in to get LYT
   * Transfer LYT from user to cover flashloan
4. Swap exact LYT to get YT
   * Flashloan a bunch of LYT
   * Calculate how much `yOut` YT to mint from LYT
     * TODO: Solve equations for `yOut`
   * Follow the same steps as 3

### LYT Trading Router:
* This is a routing system to swap LYT against any token
* We will be using a number of other AMMs, which could include
  * UniswapV2 clones [to be supported first]
  * UniswapV3
* Each of these AMMs will be wrapped to have these two interfaces:
  * SwapExactIn(address tokenIn, address tokenOut, uint256 amountIn, address[] path)
  * SwapExactOut(address tokenIn, address tokenOut, uint256 amountOut, address[] path)
* To swap LYT to ANYTOKEN:
  * Steps:
    * Redeem LYT to get its deposit assets
    * Swap the deposit assets to ANYTOKEN
  * Swap exact LYT to ANYTOKEN:
    * Just get the deposit tokens and SwapExactIn each of them into ANYTOKEN
  * Swap LYT to exact `a` ANYTOKEN:
    * If there are more than one deposit assets, we need to calculate the `a1` = amount of ANYTOKEN from deposit asset 1, and `a2` = amount of ANYTOKEN from deposit asset 2
      * Such that, `a1 + a2 = a` and the amounts of deposit asset 1 and deposit asset 2 needed to SwapExactOut to `a1` and `a2` are of the same proportion as the LYT's composition
      * How ? Either by closed form formula or binary searching
* To swap ANYTOKEN to LYT:
  * Steps:
    * Swap ANYTOKEN to the deposit assets
    * Mint the LYT with the deposit assets
  * Swap exact ANYTOKEN to LYT:
    * Similarly, if there are more than one deposit assets, we needs to calculate the proportion of ANYTOKEN to swap to the deposit assets
      * Either by closed form formula or binary searching
  * Swap ANYTOKEN to exact LYT:
    * Just SwapExactOut to get the deposit assets to mint the exact amount of LYT

### Yield Market Router:
* This is the user facing router to execute all the trades
* Swapping logic:
  * For ANYTOKEN vs YT, we just swap ANYTOKEN vs LYT and LYT vs YT
  * For ANYTOKEN vs OT, we just swap ANYTOKEN vs LYT and LYT vs OT
* Order settings:
  * Slippage:
    * We can add slippage settings in the swap functions, and revert when they are not satisfied
      * For swapping exact in: have a `minOutAmount` setting
      * For swapping exact out: have a `maxInAmount` setting
  * Deadline:
    * Beyond a certain timestamp, the trade will auto revert
  * [Nice to have, to be added later] Limit orders using 0x:
    * A user can sign a limit order on 0x to trade YT/OT against anything
    * Arbitragers can trigger these limit orders (if they are within the range of the AMM) to get the spread
    * Market makers can use these limit orders to market make
* [Nice to have, to be added later] 0x adapter:
  * Any user can trade YT/OT against any token, by filling a 0x limit order
  * The 0x adapter can split an order into 2 portions:
    * One portion to fill a 0x limit order
    * Another portion to use our AMM
  * TODO: Study how 1inch does it
  

