// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../../base-implementations/SCYBaseWithDynamicRewards.sol";
import "../../../../interfaces/ConvexCurve/IBooster.sol";
import "../../../../interfaces/ConvexCurve/IRewards.sol";
import "../../../../interfaces/Curve/ICrvPool.sol";

/*
Convex Curve LP Tokens Staking:

2 ways to stake:

1. Only deposit CurveLP Token -> Convert half to wrapped CurveLP Token and provide liquidity to the pool (under the hood)
2. Only deposit wrapped CurveLP Token -> Unwrap half into CurveLP token and provide liquidity (under the hood)
3. Deposit half wrapped CurveLP and half CurveLP to the pool.




Yield Generating Mechanism - Stake Curve LP Tokens (or wrapped version directly)

Asset - Curve LP Token

Shares - Amount of Curve LP Token or Wrapped Curve LP Token

Exchange Rate - 1:1 Curve LP Token (or Wrapped) to SCY.


**Rewards on Curve LP Token Staking on Convex:

1. Base Curve vAPR -> Curve Lp Token deposited in the pool (i.e. when you deposit 100 cvxethCRV -> get back 100 cvxethCRV after time BUT, these 100 cvxethCRV is ENTITLED to claiming MORE LIQUIDITY from the Curve Pool.)

2. CRV vAPR -> Gain CRV tokens (which includes the boost power from veCRV from Convex side)

3. CVX vAPR -> Gain CVX tokens from it.

*Note: 
1. Base rewards from Rewards Contract of Curve LP Staking Pool i.e. BaseRewardsPool.rewardToken -> Curve DAO Token

2. Extra Rewards from Rewards Contract of Curve LP Staking Pool [UNIQUE TO EACH POOL] i.e. BaseRewardsPool.extraRewards (can be more than 1, each pointing to ANOTHER BaseRewardsPool Contract WITH NO EXTRA REWARDS FEATURE which as also a native rewardToken).rewardToken -> Convex Token 


3. Depositor Contract (Booster.sol) [UNIVERSAL] -> Handles all the deposits, withdrawals and claiming of rewards.

**Pay Attention to PoolInfo inside Booster.sol -> using pid -> can retrieve the following addresses:

 - lptoken (Pool's lpToken that will be deposited i.e. for cvxeth pool -> cvxethCRV token)
 - guage    (Deposit Gauge)
 - stash    (ExtraStashV3 -> unique to each PID -> tokenList contains CVX Token.)
 - token [also known as WRAPPED cvxethCrv]    (Deposit Token cvxcrvCVXETH (Staking Token for baseRewardsPool Rewards Contract) -> To mint and stake in the baseRewardsPool Contract to EARN CRV Tokens)
 - crvRewards (Rewards Contract i.e. BaseRewardsPool -> .rewardToken is CRV Token -> extraRewards.rewardToken = CVX)


- deposit function: can do deposit(_amount) or depositAll() -> call Rewards Contract to stake


**Under Rewards Contract:

1. Withdraw And Unwrap -> BURN cvxcrvCVXETH (Curve cvx-eth Convex Deposit) -> Transfer CrvcvETH (lpToken) to Convex Finance: Voter proxy which is also Curve CVX-ETH -> Voter Proxy BURNS crvcvxETH GAUGE DEPOSIT (upon receiving the lptoken)  -> Voter Proxy then sends Curve cvxETH to BOOSTER -> BOOSTER returns Cruve cvxETH to owner;
https://etherscan.io/tx/0x9462dc97a8a5e5028298c1a9504e256f02258e3f8dd6c9453844a83db33e91cb

2. Claim Rewards -> Rewards Contract sends CRV token to user  + [BOOSTER contract] mints CVX to user + Additional Rewards transferred to user from 'ExtraRewards' virtualBalancePool contracts


**Exceptions:

- Some pools has ADDITIONAL REWARDS (apart from base Curve LP token, CRV & CVX):

i.e. sUSD -> Additional SNX rewards (lies in the 'extraRewards' inside Base Rewards Contract)
i.e. saave -> Additional stAAVE rewards.

Weird Stuff: 

1. Some 'extraRewards' in BaseRewardsPool denominate CVX as one of them i.e. cvxEth, while some don't i.e. sUSD.

But both still receive CVX as rewards, so need to make sure _getRewardTokens do not have a duplicated address. CVX (and also CRV) will be hardcoded into the rewardTokens array since both are present in ALL Convex Curve LP Staking Pool.


Miscellaneous Notes: 

operator -> Convex Finance BOOSTER Contract.

[UNIVERSAL] BOOTER Contract (i.e. Deposit Contract) -> 0xb1Fb0BA0676A1fFA83882c7F4805408bA232C1fA

CRV Token ERC20 Contract -> 0xD533a949740bb3306d119CC777fa900bA034cd52

CVX Token ERC20 Contract -> 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B

*/

abstract contract PendleConvexCurveLPSCY is SCYBaseWithDynamicRewards {
    using SafeERC20 for IERC20;

    uint256 public immutable PID;
    address public immutable BOOSTER; // set as immutable instead
    address public immutable BASE_REWARDS;
    address public immutable BASE_CRV_POOL;

    address public immutable CRV;
    address public immutable CVX;

    address public immutable CRV_LP_TOKEN;
    address public immutable W_CRV_LP_TOKEN; // To Add.

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _pid,
        address _convexBooster,
        address _wrappedLpToken,
        address _cvx,
        address _baseCrvPool,
        address[] memory _currentExtraRewards
    )
        // To Change _yieldToken
        SCYBaseWithDynamicRewards(_name, _symbol, _wrappedLpToken, _currentExtraRewards)
    {
        require(_convexBooster != address(0), "zero address");
        require(_wrappedLpToken != address(0), "zero address");
        require(_cvx != address(0), "zero address");
        require(_baseCrvPool != address(0), "zero address");

        PID = _pid;
        CVX = _cvx;
        W_CRV_LP_TOKEN = _wrappedLpToken;
        BASE_CRV_POOL = _baseCrvPool;

        BOOSTER = _convexBooster;
        (CRV_LP_TOKEN, BASE_REWARDS, CRV) = _getPoolInfo(PID);

        _safeApprove(CRV_LP_TOKEN, BOOSTER, type(uint256).max);
        _safeApprove(W_CRV_LP_TOKEN, BOOSTER, type(uint256).max);
    }

    function _getPoolInfo(uint256 pid)
        internal
        view
        returns (
            address lptoken,
            address crvRewards,
            address crv
        )
    {
        require(pid <= IBooster(BOOSTER).poolLength(), "invalid pid");

        (lptoken, , , crvRewards, , ) = IBooster(BOOSTER).poolInfo(pid);
        crv = IBooster(BOOSTER).crv();
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SCYBase-_deposit}
     *
     * The underlying yield token is CRV_LP_TOKEN. Apart from accepting CRV_LP_TOKEN, Wrapped CRV_LP_TOKEN for staking in baseRewardsPool contract can be accepted also. Then the corresponding amount of shares is returned.
     *
     * The exchange rate of CRV_LP_TOKEN (or wrapped CRV_LP_TOKEN) to SCY is based on existing liquidity
     */
    function _deposit(address tokenIn, uint256 amount)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == CRV_LP_TOKEN) {
            IBooster(BOOSTER).deposit(PID, amount, true);
        } else {
            IRewards(BASE_REWARDS).stakeFor(address(this), amount);
        }
        amountSharesOut = amount;
    }

    /**
     * @dev See {SCYBase-_redeem}
     *
     * The shares are redeemed into the same amount of CRV_LP_TOKEN or W_CRV_LP_TOKEN . Hence `tokenOut` will only be the underlying asset (wrapped or unwrapped version) in this case. Since there will NOT be any withdrawal fee from Convex Curve LP Staking, amountSharesToRedeem will always correspond amountTokenOut.
     */
    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == CRV_LP_TOKEN) {
            // Withdraw and unwrap from W_CRV_LP_TOKEN to CRV_LP_TOKEN without claiming rewards
            IRewards(BASE_REWARDS).withdrawAndUnwrap(amountSharesToRedeem, false);
        } else {
            // Withdraw W_CRV_LP_TOKEN without claiming rewards
            IRewards(BASE_REWARDS).withdraw(amountSharesToRedeem, false);
        }
        amountTokenOut = amountSharesToRedeem;
    }

    function _previewDeposit(address, uint256 amountTokenToDeposit)
        internal
        view
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        amountSharesOut = (amountTokenToDeposit * 1e18) / exchangeRate();
    }

    function _previewRedeem(address, uint256 amountSharesToRedeem)
        internal
        view
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        amountTokenOut = (amountSharesToRedeem * exchangeRate()) / 1e18;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exchange rate for CURVE_LP_TOKEN to SCY is the amount of liquidity it is entitled to redeeming which will increase over time.
     * @dev It is the exchange rate of Shares in Convex Curve LP Staking to its underlying asset (CURVE_LP_TOKEN).
     *
     * The current price of the pool LP token relative to the underlying pool assets. Given as an integer with 1e18 precision.
     *
     */
    function exchangeRate() public view override returns (uint256) {
        return ICrvPool(BASE_CRV_POOL).get_virtual_price();
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-getRewardTokens}
     *Most pools have a default CVX reward minted directly from the BOOSTER contract upon claiming rewards, however, some BaseReward Pools like CrvcvxETH have 'extraRewards' in CVX also -> Need to ensure there is NO DUPLICATED CVX Address inside.
     **/
    function _getRewardTokens() internal view override returns (address[] memory res) {
        return currentExtraRewards;
    }

    function _redeemExternalReward() internal override {
        // Need to interact with the BaseRewardsPool Contract:
        IRewards(BASE_REWARDS).getReward();
    }

    /*///////////////////////////////////////////////////////////////
                    MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-getBaseTokens}
     */
    function getBaseTokens() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = CRV_LP_TOKEN;
        res[1] = W_CRV_LP_TOKEN;
    }

    /**
     * @dev See {ISuperComposableYield-isValidBaseToken}
     */
    function isValidBaseToken(address token) public view virtual override returns (bool res) {
        res = (token == CRV_LP_TOKEN || token == W_CRV_LP_TOKEN);
    }

    function assetInfo()
        external
        view
        returns (
            AssetType assetType,
            address assetAddress,
            uint8 assetDecimals
        )
    {
        // Curve's pool can vary from 2 - 4 assets -> can create 3 different contracts for gas optimisation.
        // Ask greg long and vu -> support base token of a-usdc ... and a-dai
        // Should be liquidity instead of token:
        // Tri-Curve LP -> Base Token can contain USDC, USDT and DAI -> if user used router and how does user use the router to get to SCY - use router -> HOW TO get pendle (To GET TO SCY) to swap into some stable tokens -> no way to convert a-USDC into SCY -> should support USDC DAI to get into SCY.
        return (AssetType.LIQUIDITY, CRV_LP_TOKEN, IERC20Metadata(CRV_LP_TOKEN).decimals());
    }
}
