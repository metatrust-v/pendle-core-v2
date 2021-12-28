### Overview
- There are multiple protocols/strategies for generating reward in DeFi:
    - Lend tokens to a money market (Compound/Aave)
    - Provide liquidity to an AMM
    - Stake some tokens to farm some incentive tokens (all liquidity mining programs)
    - Stake some tokens to a strategy/vault to get more of the same tokens, or other tokens (Yearn, Harvest, Autofarm,...)
- Let's try to generalise all these reward generating mechanisms into a general framework


### Let's define some basic terms
For each reward generating mechanism, let's define the following terms:

- **Deposit assets**: the asset(s) that are deposited, to generate the reward
    - E.g: In providing liquidity to Uniswap, the **deposit assets** are the two pool tokens
- **Accounting asset**: the asset whose balance is used to calculate the reward
    - In most cases, the **accounting asset** is the same as the **deposit asset**
        - E.g: Compound, Aave, liquidity mining,...
    - In providing liquidity to an AMM, the **accounting asset** is usually the **liquidity**
- **Reward assets**: the assets that are gained from having a position of the **accounting asset in the protocol over time**
  

### The two types of reward generating mechanisms:
1. **Accounting assets** generates more **accounting assets** over time (with auto compound)
   - In other words, the reward asset is the same as the **accounting assets**, and it's compounded into the **accounting assets** balance of the user
   - Let's define some more terms:
     -  **pool shares**: an asset that the user gets after depositing **accounting assets**, that represents their share in the reward generating pool
         - As the pool generates more reward in terms of **accounting assets**, 1 pool share can exchange for more **accounting assets**
         - E.g:
           - In Compound: pool shares = cDAI
           - In AaveV2: pool shares = `scaledBalanceOf`
           - For UniswapV2 LP: pool shares = LP tokens
     - **exchange rate**: how many **accounting asset **is 1 pool share worth
         - = total amount of **accounting assets** in the pool / total supply of pool shares
         - E.g:
             - In Compound: `exchangeRateCurrent`
             - In Aave: normalised income
             - In UniswapV2: total liquidity / totalSupply of Lp token
   - How is reward calculated ?
      -  When user deposits **deposit assets**:
         - Calculate how much **accounting assets** are equivalent to the **deposit assets**
         - Mint **pool shares** to user according to current **exchange rate**
     - When user withdraw:
         - Calculate how much **accounting assets** is the **pool share** worth, based on current **exchange rate**
         - Convert the **accounting assets** to **deposit assets**
2. **Accounting assets** generate other reward assets over time (simple interest)
    - The pool generates some **reward assets** over time
    - The **reward assets** are distributed equally among the users, proportionally to their **accounting asset** balance