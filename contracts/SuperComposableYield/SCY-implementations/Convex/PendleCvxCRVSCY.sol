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

1. Base rewards from Rewards Contract of cvxCrv Staking Pool i.e. BaseRewardsPool.rewardToken -> Curve DAO Token

2. Extra Rewards from Rewards Contract of cvxCrv Staking Pool i.e. BaseRewardsPool.extraRewards (length of 1 in this case, pointing to ANOTHER VirtualBalancePool Contract WITH NO EXTRA REWARDS FEATURE which also has a rewardToken).rewardToken -> 3Crv


3. Depositor Contract (CrvDepositor) -> Handles all the deposits, withdrawals and claiming of rewards.


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
    function _redeem(address, uint256 amountSharesToRedeem)
        internal
        override
        returns (uint256 amountTokenOut)
    {
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
        amountSharesOut = amountTokenToDeposit;
    }

    function _previewRedeem(address, uint256 amountSharesToRedeem)
        internal
        pure
        override
        returns (uint256 amountTokenOut)
    {
        amountTokenOut = amountSharesToRedeem;
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
