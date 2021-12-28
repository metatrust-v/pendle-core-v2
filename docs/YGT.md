### Reward Generating Token
Reward Generating Tokens (YGT) are tokens that generate other tokens, as users hold it over time.

##### Interface for Reward Generating Token:
* `address[] rewardTokens`
  * List of reward tokens that a user will get by holding the YGT
* `claimReward(bool[] isClaiming, address user)`
* `delegateRewardDestination(address)`
* `accruedRewards(address user) returns uint256[]`
* All the ERC20 interfaces
