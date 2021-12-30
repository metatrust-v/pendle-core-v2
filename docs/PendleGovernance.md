# Pendle Governance
[Back](PendleV2.md)

### xPENDLE
* xPENDLE is minted by locking PENDLE for a duration (from 1 week to 4 years)
  * `xPendleMinted = pendleLocked * lockingDuration / fourYears`
* xPENDLE balance decays linearly over time
  * Each user's xPENDLE position is represented by `a` and `b`, which are the parameters for the line representing their xPENDLE balance over time
    * `w_user(t) = b - a * t`
* Actions user can do:
  * Create new lock:
    * This is when a user starts locking for the first time
    * We initiate a new `a` and `b` for them
  * Increase amount:
    * User adds more PENDLE to their current locking schedule
    * Update `a` and `b`
    * Mint extra xPENDLE (equal to increase in b)
  * Increase unlock time:
    * Update `a` and `b` to reflect longer unlock time
    * Mint extra xPENDLE (equal to increase in b)
  * Withdraw:
    * When `w_user(t)` is <= 0, give PENDLE back to the user
* Total xPENDLE supply:
  * The total supply `W(t) = B - A * t` where B is the sum of all `b` and `A` is the sum of all `A`
  * We just keep track of `A` and `B`

### Liquidity Mining pools' PENDLE allocation
* There is a fixed rate `R` of PENDLE per second for liquidity mining
* There are multiple liquidity mining pool types, each identified by a string id (bytes32)
* Each pool type has a weight `w_poolType`
* There are multiple pools in each pool type, each identified by the pool address
* Each pool has a weight `w_pool`
* Each pool will get PENDLE incentives at a rate proportional to `w_poolType * w_pool`

### Voting on liquidity mining pools
* xPENDLE holders can allocate their vote among a number of pools
* `w_poolType` and `w_pool` will be decided based on the xPENDLE votes, on a weekly basis

### Boosted liquidity incentives for xPENDLE holders
* Within each pool, a user will have a balance of `b_u