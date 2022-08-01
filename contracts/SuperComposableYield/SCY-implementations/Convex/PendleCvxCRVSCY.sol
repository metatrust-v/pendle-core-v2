// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../base-implementations/SCYBaseWithDynamicRewards.sol";
import "../../../interfaces/ConvexCurve/ICrvDepositor.sol";
import "../../../interfaces/ConvexCurve/IRewards.sol";
import "../../../interfaces/ConvexCurve/ICvxCrv.sol";

/*
CRV -> CvxCRV Staking:

*One way conversion from CRV to cvxCRV and then staked. Unstaking can be done anytime. 




Yield Generating Mechanism - Stake CRV (or cvxCRV directly) into cvxCRV and stake  

Asset - CRV/cvxCRV Token

Shares - Amount of CRV/cvxCRV Token staked.

Exchange Rate - CRV/cvxCRV : SCY should be 1 : 1


**Rewards on Curve LP Token Staking on Convex:

1. CRV vAPR -> Gain CRV Tokens (which includes boosted rewards from veCRV from Convex Side)

2. CVX vAPR -> Gain CVX Tokens from token emissions.

3. 3crv vAPR -> Gain  Curve.fi DAI/USDC/USDT (3Crv) from 'extraRewards' from BaseRewardsPool of this staking pool.

*Note: 

1. Base rewards from Rewards Contract of crvCvx Staking Pool i.e. BaseRewardsPool.rewardToken -> Curve DAO Token

2. Extra Rewards from Rewards Contract of crvCvx Staking Pool i.e. BaseRewardsPool.extraRewards (length of 1 in this case, pointing to ANOTHER VirtualBalancePool Contract WITH NO EXTRA REWARDS FEATURE which also has a rewardToken).rewardToken -> 3Crv


3. Depositor Contract (CrvDepositor) -> Handles all the deposits, withdrawals and claiming of rewards.




- deposit function: can do deposit(_amount) or depositAll() -> call Rewards Contract to stake


**Under Rewards Contract:

1. Withdraw And Unwrap -> BURN cvxcrvCVXETH (Curve cvx-eth Convex Deposit) -> Transfer CrvcvETH (lpToken) to Convex Finance: Voter proxy which is also Curve CVX-ETH -> Voter Proxy BURNS crvcvxETH GAUGE DEPOSIT (upon receiving the lptoken)  -> Voter Proxy then sends Curve cvxETH to BOOSTER -> BOOSTER returns Cruve cvxETH to owner;
https://etherscan.io/tx/0x9462dc97a8a5e5028298c1a9504e256f02258e3f8dd6c9453844a83db33e91cb

2. Claim Rewards -> Rewards Contract sends CRV token to user  + [BOOSTER contract] mints CVX to user + Additional Rewards transferred to user from 'ExtraRewards' virtualBalancePool contracts



Weird Stuff: 

1. Some 'extraRewards' in BaseRewardsPool denominate CVX as one of them i.e. cvxEth, while some don't i.e. sUSD.

But both still receive CVX as rewards, so need to make sure _getRewardTokens do not have a duplicated address. CVX (and also CRV) will be hardcoded into the rewardTokens array since both are present in ALL Convex Curve LP Staking Pool.


Miscellaneous Notes: 

operator -> Convex Finance BOOSTER Contract.

[UNIVERSAL] BOOTER Contract (i.e. Deposit Contract) -> 0xb1Fb0BA0676A1fFA83882c7F4805408bA232C1fA

CRV Token ERC20 Contract -> 0xD533a949740bb3306d119CC777fa900bA034cd52

cvxCRV Token ERC20 Contract -> 0x62b9c7356a2dc64a1969e19c23e4f579f9810aa7

CVX Token ERC20 Contract -> 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B

crv -> cvx Rewards Contract (BaseRewardsPool) -> 0x3Fe65692bfCD0e6CF84cB1E7d24108E434A7587e

crvCVX Staking Deposit Contract (CrvDepositor) -> 0x8014595F2AB54cD7c604B00E9fb932176fDc86Ae

*/

contract PendleCvxCRVSCY is SCYBaseWithDynamicRewards {
    address public immutable CRV_DEPOSITOR;
    address public immutable BASE_REWARDS;

    address public immutable CRV;
    address public immutable CVX;
    address public immutable CVX_CRV;

    constructor(
        string memory _name,
        string memory _symbol,
        address _cvxCrv,
        address _cvx,
        address _baseRewards,
        address[] memory _currentExtraRewards
    ) SCYBaseWithDynamicRewards(_name, _symbol, _cvxCrv, _currentExtraRewards) {
        require(_cvxCrv != address(0), "zero address");
        require(_cvx != address(0), "zero address");
        require(_baseRewards != address(0), "zero address");

        CVX_CRV = _cvxCrv;
        CVX = _cvx;
        BASE_REWARDS = _baseRewards;

        // Retrieve CrvDepositor contract
        CRV_DEPOSITOR = ICvxCrv(CVX_CRV).operator();

        // Retrieve underlying token crv
        CRV = ICrvDepositor(CRV_DEPOSITOR).crv();

        _safeApprove(CRV, CRV_DEPOSITOR, type(uint256).max);
        _safeApprove(CVX_CRV, CRV_DEPOSITOR, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SCYBase-_deposit}
     *
     * The underlying yield token is CVX_CRV. Apart from accepting CRV, CVX_CRV can be directly accepted for staking in baseRewardsPool contract. Then the corresponding amount of shares is returned.
     *
     * Conversion of CRV -> CVX_CRV is ONE-WAY.
     *
     * The exchange rate of CRV (or CVX_CRV) to shares is 1:1
     */
    function _deposit(address tokenIn, uint256 amount)
        internal
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == CRV) {
            // Why false, defer someone to lock up? -> Save gas since someone will call lock function periodically.
            ICrvDepositor(CRV_DEPOSITOR).deposit(amount, false, BASE_REWARDS);
        } else {
            IRewards(BASE_REWARDS).stakeFor(address(this), amount);
        }
        amountSharesOut = amount;
    }

    /**
     * @dev See {SCYBase-_redeem}
     *
     * The shares are redeemed into the same amount of cvxCrv . Hence `tokenOut` will only be the underlying asset  in this case. Each time 'withdraw' is called from BaseRewardsPool contract, it will update extraRewards. Since there will NOT be any withdrawal fee from cvxCrv Staking, amountSharesToRedeem will always correspond amountTokenOut.
     */
    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        override
        returns (uint256 amountTokenOut)
    {
        // Just an additional check since CRV will disappear after staking. Can be implemented in external function also.
        require(tokenOut != CRV, "CRV cannot be withdrawn from Cvx-CRV");
        IRewards(BASE_REWARDS).withdraw(amountSharesToRedeem, false);
        amountTokenOut = amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exchange rate for CvxCRV to SCY is 1:1
     * @dev It is the exchange rate of Shares in cvxCRV Staking to its underlying asset (cvxCRV)
     */
    function exchangeRate() public pure override returns (uint256) {
        return SCYUtils.ONE; // No interest coming from them , just the token
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-getRewardTokens}
     *Get Extra Rewards from SCYBaseWithDynamicRewards Contract immutable variables. To update, simply use a proxy and update with the new rewards.
     **/
    function _getRewardTokens() internal view override returns (address[] memory res) {
        return currentExtraRewards;
    }

    /**
     * @dev Receive all rewards from the pool which includes CRV, CVX and 3CRV emissions
     */
    function _redeemExternalReward() internal override {
        IRewards(BASE_REWARDS).getReward();
    }

    /*///////////////////////////////////////////////////////////////
                    MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(address, uint256 amountTokenToDeposit)
        internal
        pure
        override
        returns (uint256 amountSharesOut)
    {
        amountSharesOut = (amountTokenToDeposit * 1e18) / exchangeRate();
    }

    function _previewRedeem(address, uint256 amountSharesToRedeem)
        internal
        pure
        override
        returns (uint256 amountTokenOut)
    {
        amountTokenOut = (amountSharesToRedeem * exchangeRate()) / 1e18;
    }

    function getTokensIn() public view override returns (address[] memory res) {
        res = new address[](2);
        res[0] = CRV;
        res[1] = CVX_CRV;
    }

    function getTokensOut() public view override returns (address[] memory res) {
        res = new address[](1);
        res[0] = CVX_CRV;
    }

    function isValidTokenIn(address token) public view override returns (bool res) {
        res = (token == CRV || token == CVX_CRV);
    }

    function isValidTokenOut(address token) public view override returns (bool res) {
        res = (token == CVX_CRV);
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
        return (AssetType.TOKEN, CVX_CRV, IERC20Metadata(CVX_CRV).decimals());
    }
}
