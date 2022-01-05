## A. Update 4626:
- Add notion of value vs deposit token
- still only works with compounding yield

## Another standard on top of 4626:
- Add reward tokens and rewardIndexes
  
  
Deposit tokens (cDAI, LP)

Accounting unit (USDC, liquidity)

Shares


## Points:
- 4626 is **replacing** the current yield bearing tokens
- LYT can be on top of current yield bearing tokens


## Our line of thinking:
Do we want to ask 4626 to be compatible with us at all?



The options:
1. Ignore 4626, launch our LYT later for anything yield bearing (wrapped or direct)
    - Cons:
      - We are "fighting" with 4626 for introducing a standard
      - During the "4 months" period, 4626 already gain some traction, maybe some projects already start adopting it
     - 

2. Ask 4626 to change certain interfaces so that LYT would be compatible to  4626 (LYT extends 4626)
   2.a.
     Only ask for minimal changes(A) to 4626, so that LYT can be extended from it.
        -> In 4 months, we propose 48xx (inherits 4626) -> LYT -> have reward tokens
        Cons:
            Our LYT for LP will always be a wrapped version (user deposit LP tokens -> LYT) -> Can just use zap outside of LYT for users to deposit raw assets

   2.b.
     Ask 4626 to add all the LYT interfaces (Reward tokens, reward claiming) -> 4626 = LYT

3. Propose LYT right now/soon as a separate EIP
   1. 
   
other notes:
### Current 4626 limitations:
- current 4626 cannot work with LPs
  - Not really, it can still work for Yearn - CrvLP
- 4626 cannot work with yield tokenisation of LPs
- 