# Yield Splitter
[Back](PendleV2.md)

### How it works
* When tokenising `l` LYTs which is worth `a = l * lyt.exchangeRate()` accounting assets, we will mint `a` OTs and `a` YTs
* Each YT is a Yield Generating Token
  * `address[] rewardTokens`
    * The rewardTokens array here is lyt.rewardTokens with another extra item which is the lyt token itself
    * Let's call lyt the **primary reward token** and the other reward tokens as **secondary reward tokens**
  * `claimReward(bool[] isClaiming, address user)`
    * The `isClaiming` array has another element for the lyt reward
  * `delegateRewardDestination(address)`
  * `accruedRewards(address user) returns uint256[]`
  * All the ERC20 interfaces
* Accounting for YT's rewards:
  * For the **secondary reward tokens**:
    * Save `lastRewardIndexes` for each user
    * Before transfering YT: accrue the secondary reward tokens to the sender and receiver
      * accruedRewards[user][rewardTokenIndex] += ytBalance * (currentRewardIndex - lastRewardIndex)
    * Save lastRewardIndexesBeforeExpiry to use as the estimated rewardIndexes at the expiry
  * For the **primary reward token**:
    * Save `lastExchangeRate` for each user
    * Before transfering YT: accrue the primary reward token to the sender and receiver
      * `accruedRewards[user][primayRewardTokenIndex] += ytBalance * (currentExchangeRate/lastExchangeRate - 1) / currentExchangeRate`
    * Save lastExchangeRateBeforeExpiry to use as the estimated exchangeRate at the expiry
