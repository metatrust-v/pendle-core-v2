# xPENDLE 

## Specs

To obtain xPendle, users will lock Pendle into xPendle contract. At any time, an user's xPENDLE balance should be:

$
B^{u} = p_u \times t_u
$ 
$p_u$ = amount of Pendle locked, $t_u$ = amount of time left to the end of the lock.


Users can use his xPENDLE balance to vote for Liquidity Mining reward for LP pools. We have:
$
\sum V^{u}_p \leq B^{u}
$
where $V^{u}_p$ is the number of xPendle users are voting on pool $p$.

Liquidity minings are divided into types according to Pendle's decision. Among a type, Pendle's liquidity mining incentives will be divided into liquidity minings respecting to their proportion of xPENDLE voted. 

$
R_{p_0} = \frac{R_{type}}{\sum V^{u}_p} \times V_{p_0}
$

where $R_{type}$ is the total amount of reward incentives for this epoch.

Rewards for one Liquidity Mining will be distributed according to amount of LP users deposited **for each timestamp** (same as our current OT reward distribution).

One difference, instead of users' LP deposited, we are accounting for xPENDLE balance as well:
$
LP'_u = min(0.4 \times LP_u + 0.6 \times B^{u}, LP_u)
$

So, one will only receive his full reward for $LP$ if he has a sufficient amount of xPENDLE.


## Discussions

### **a) Voting crosschain issue**

Pendle has now been launched on both Ethereum, Avalanche and probably some other chains for our V2 as well. If we are not gathering the LMs votes on one chain, we will have to be the one who decide on the incentives for each chain. 

Plus, liquidity mining for a pool should be placed on the same chain as the pool itself, so liquidity mining will not be able to acknowledge the accurate amount of xPENDLE of each user.

* **Solution 1**: Decide on the incentives for chains, take xPENDLE balance away from the LM reward distribution
    
    **Pros**: Easy, super easy to implement.

    **Cons**: Took away the FOMO vibe of the formula. Quite centralized to decide on what the incentives.

* **Solution 2**: Send messages crosschain to sync up on users' xPENDLE balance
    
    **Pros**: FOMO formula. Makes everything **accurate**.

    **Cons**: Hard to implement, test, have to wait until Celer launch to have the final decision. Crosschain fee?

### **b) Hard/Soft governance**

The first requirement of hard governance is the solution a.2, so we will have a discussion on the assumption that a.2 is chose in the case of hard governance.

For the context, Curve is not doing the hard governance but rather a soft one, since they have the ability to set some liquidity mining's vote to something they want. 

* **Soft Governance:**
On the a.2, we only send a crosschain message everytime users' xPENDLE balance changes. What is left is every time their voting is changed, we haven't decided to send a message to update all the chains about the informations of voting. Therefore, Pendle needs to be reserved the right to send a transaction to incentive the pools respecting to the voting results.

* **Hard Governance:** 
In order to make a hard governance, every time an user vote, we will need to send one or more crosschain message to sync up the voting results. If this is possible, the system should work smoothly without having users to trust Pendle.

### **c) More on the hard/soft**

Curve is also reserved the right to decide on the $R_{type}$ and thats the model we are following up until now. This also makes us less of a hard governance. If we are choosing to be hard governance, and remove the $type$ for each liquidity mining, we will be fully decentralized on the reward distribution.

### **d) Locking LP**

You probably have understood the idea behind xPENDLE balance above. I would like to propose a further step on our Liquidity Mining with the same idea. If an user is locking $X$ LP for a period of $t$ seconds, I propose that his LP balance should be:

$
LP_u = X \times t
$

where $LP_u$ is calculated on the last action user took on the liquidity mining. The formula for $LP'_u$ is left unchanged.

This encourages users to lock his LP longer for more pendle rewards, therefore creating a better experience for traders on OT-LYT pools.