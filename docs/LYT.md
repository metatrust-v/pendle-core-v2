# Liquid Yield Token
[Back](PendleV2.md)

### Yield Generating Tokens
* [Link to details](YGT.md)

### LYT overview
* LYTs are YGTs
* LYTs are basically a standard for any reward generating mechanism in DeFi

### Generalising DeFi's reward generating mechanisms
* [Link to details](DeFiReward.md)

### LYT's interface
LYT has all the interfaces from YGT:
* `address[] rewardTokens`
* `claimReward(bool[] isClaiming, address user)`
* `delegateRewardDestination(address)`
* `accruedRewards(address user) returns uint256[]`
* All the ERC20 interfaces

With some additional interfaces:
* `uint256[] rewardIndexes`
* `uint256 exchangeRate`
* `address depositAssets[]`
* `mint(uint256[] depositAssetAmounts, address to) returns (uint256 poolShares)`
* `burn(uint256 poolShares) returns (uint256[] depositAssetAmounts)`
* `updateAccounting(bool forceUpdate)`
  * Update global reward accounting (exchange rate and rewardIndexes)
  * if `forceUpdate` is true, bypass the caching mechanism and always update the indexes

### How it works
* When depositing **deposit assets**, the amount of LYT minted will be the same as the pool share of the reward generating mechanism
* When withdrawing **deposit assets**, the amount of **accounting assets**-equivalent the user gets will be proportional to their pool shares
* As such, LYT will be worth more of the **accounting asset** overtime
  * This also means that when transfering LYTs, the compounded reward on the accounting assets is transfered together with the tokens
* For the other reward tokens (with simple interest), they are accrued to each user proportionally to their pool shares
  * When transfering LYTs, the accrued reward tokens stay with the sender

### Caching of rewards
* In the actual implementation, there could be settings for a `cachingThreshold` percentage for the exchange rate and for each rewardIndex
* If the exchange rate or the rewardIndex doesn't exceed the threshold, doesn't update the indexes
