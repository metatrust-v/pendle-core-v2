# OT AMM
* [Back](YieldMarket.md)
### Overview
* This is a an AMM for trading OT against its corresponding LYT
* The AMM design aims to achieve a few things
  * It's capital efficient, which allows for trading relatively large size with low slippage
  * It preserves a consistent interest rate over time (interest rate continuity), if no trades happen
    * It means that people should only trade with the AMM if they think the interest will change, and not because of other factors like underlying asset price or time
  * It will dynamically change its formula over time to approach a constant sum formula (1 OT = 1 accounting asset) after the expiry
  * It allows for explicitly setting the tradeoff between capital efficiency and the reasonable trading range
  
### Virtual accounting asset balance
* Although the actual tokens sitting in the AMM's account are OT and LYTs, from the AMM's perspective, we will pretend that we have OT and accounting assets instead.
* As such, this is really an AMM for trading OT against accounting assets
* In terms of how the AMM's logic works, at any point in time, we will pretend that we have `a` accounting assets and `o` OTs, where `a = lytBalance * lyt.exchangeRate()`
* Although `a` will increase by itself, we will treat it as if it's just somebody sending accounting assets into the AMM.

### The parameters
* There are 3 important parameters in the AMM:
  * `f_scalar0`: a scalar factor to adjust the initial capital efficiency (by adjusting the slope of the exchange rate graph)
  * `r_anchor0`: an initial anchor rate to anchor the initial AMM formula to be more capital efficient around that interest rate
  * `f_fees0`: the initial fees factor

### The definitions
* Time left until expiry

    ![t](https://latex.codecogs.com/svg.image?t&space;=&space;\frac{timeToExpiry}{contractDuration})

* The `p` parameter

    ![pParameter](https://latex.codecogs.com/svg.image?p=&space;\frac{otAmount}{otAmount&space;&plus;&space;accountingAssetAmount}&space;=&space;\frac{o}{o&plus;a})

* Scalar factor

    ![scalarFactor](https://latex.codecogs.com/svg.image?f_{scalar}&space;=&space;\frac{f_{scalar0}}{t})

* The marginal exchange rate, which is basically the marginal price of accounting assets in OTs

    ![marginalExchangeRate](https://latex.codecogs.com/svg.image?marginalExchangeRate&space;=&space;e_{marginal}&space;=&space;\frac{1}{f_{scalar}}&space;\times&space;ln(\frac{p}{1-p})&space;&plus;&space;r_{anchor})

* The marginal interest rate
  
    ![marginalInterestRate](https://latex.codecogs.com/svg.image?r_{marginal}&space;=&space;(e_{marginal}&space;-&space;1)&space;\times&space;\frac{1year}{timeToExpiry})

* The liquidity fees
  
    ![liquidityFees](https://latex.codecogs.com/svg.image?f_{fees}&space;=&space;f_{fees0}\times&space;t)

### Adjusting r_anchor for interest rate continuity
* After every trade, we will save the marginal interest rate post-trade as `lastRate = r_last`
* Before every trade, we will adjust `r_anchor` such that the pre-trade marginal interest rate will be exactly the same as `lastRate`
  * We calculate the new marginal interest rate pre-adjustment `r_beforeAdjustment` (using old anchor rate `r_anchorOld`)
  * Then, we calculate the newly adjusted anchor rate `r_anchorNew`
  
  ![rAnchorNew](https://latex.codecogs.com/svg.image?r_{anchorNew}&space;=&space;r_{anchorOld}&space;-&space;(r_{beforeAdjustment}&space;-&space;r_{last})&space;\times&space;\frac{timeToExpiry}{1year})

### Swapping logic
* Let's say the current reserve has `o` OTs and `a` accounting assets
* Let's say a user Alice wants to swap in `d_o` OTs (which could be negative)
* First, we adjust the anchor rate as per the previous section
* Then, we calculate the `p` parameter for the trade, which we call `p_trade`
  
    ![pTrade](https://latex.codecogs.com/svg.image?p_{trade}&space;=&space;\frac{o&space;&plus;&space;d_o}{o&plus;a})

* Then, we calculate the exchange rate according to this formula:
  
    ![exchangeRateTrade](https://latex.codecogs.com/svg.image?e_{trade}&space;=&space;\frac{1}{f_{scalar}}&space;\times&space;ln(\frac{p_{trade}}{1-p_{trade}})&space;&plus;&space;r_{anchor}&space;\pm&space;f_{fees})

    * The fees is added if `d_o` is positive, and subtracted if it's negative
* Then, we simply calculate `d_a` using the `e_trade`
  
    ![dA](https://latex.codecogs.com/svg.image?d_a&space;=&space;-&space;\frac{d_o}{e_{trade}})

* After the trade, we calculate and save the `r_last`

### Adding/removing liquidity
* For the very first liquidity addition:
  * The user can set how much OT and accounting assets to bootstrap the liquidity with
  * The user will be given back the same amount of LP tokens as the accounting asset amount
* Liquidity is added/removed proportionally in terms of OT and accounting assets
* As such, we need to convert accounting assets to and from LYT accordingly

### TWAP for OT prices
* Use the same approach as UniswapV3 to store the culmulative sums of `price * time` in an array
* Link to Uniswap docs: https://uniswap.org/blog/uniswap-v3#advanced-oracles
