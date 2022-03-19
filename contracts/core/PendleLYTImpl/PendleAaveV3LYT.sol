// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;
import "../../LiquidYieldToken/implementations/LYTWrapWithRewards.sol";
import "../../interfaces/IAToken.sol";
import "../../interfaces/IAavePool.sol";
import "../../interfaces/IAaveRewardsController.sol";
import "../../libraries/math/WadRayMath.sol";

contract PendleAaveV3LYT is LYTWrapWithRewards {
    using WadRayMath for uint256;
    using SafeERC20 for IERC20;

    address internal immutable underlying;
    address internal immutable pool;
    address internal immutable rewardsController;
    
    uint256 internal lastLytIndex;

    // WIP: Aave reward controller can config to have more rewardsToken,
    // hence rewardsLength should not be immutable
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __lytdecimals,
        uint8 __assetDecimals,
        address _aavePool,
        address _underlying,
        address _yieldToken,
        address _rewardsController,
        uint256 _rewardsLength
    ) LYTWrapWithRewards(_name, _symbol, __lytdecimals, __assetDecimals, _yieldToken, _rewardsLength) {
        pool = _aavePool;
        underlying = _underlying;
        rewardsController = _rewardsController;
        IERC20(underlying).safeIncreaseAllowance(yieldToken, type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/
    
    function _baseToYield(address, uint256 amountBase)
        internal
        virtual
        override
        returns (uint256 amountYieldOut)
    {
        uint256 preBalance = IAToken(yieldToken).scaledBalanceOf(address(this));

        IAavePool(pool).supply(underlying, amountBase, address(this), 0);

        amountYieldOut = IAToken(yieldToken).scaledBalanceOf(address(this)) - preBalance;
    }

    function _yieldToBase(address, uint256 amountYield)
        internal
        virtual
        override
        returns (uint256 amountBaseOut)
    {
        uint256 amountBaseExpected = amountYield.rayMul(lytIndexCurrent());
        amountBaseOut = IAavePool(pool).withdraw(underlying, amountBaseExpected, address(this));
    }

    /*///////////////////////////////////////////////////////////////
                DEPOSIT/REDEEM USING THE YIELD TOKEN
    //////////////////////////////////////////////////////////////*/

    function depositYieldToken(
        address recipient,
        uint256 amountYieldIn,
        uint256 minAmountLytOut
    ) public virtual override returns (uint256 amountLytOut) {
        IERC20(yieldToken).safeTransferFrom(msg.sender, address(this), amountYieldIn.rayMul(lytIndexCurrent()));

        amountLytOut = amountYieldIn;

        require(amountLytOut >= minAmountLytOut, "insufficient out");

        _mint(recipient, amountLytOut);
    }

    function redeemToYieldToken(
        address recipient,
        uint256 amountLytRedeem,
        uint256 minAmountYieldOut
    ) public virtual override returns (uint256 amountYieldOut) {
        _burn(msg.sender, amountLytRedeem);

        amountYieldOut = amountLytRedeem;

        require(amountYieldOut >= minAmountYieldOut, "insufficient out");

        IERC20(yieldToken).safeTransfer(recipient, amountYieldOut.rayMul(lytIndexCurrent()));
    }

    /*///////////////////////////////////////////////////////////////
                               LYT-INDEX
    //////////////////////////////////////////////////////////////*/

    function assetBalanceOf(address user) public virtual override returns (uint256) {
        return balanceOf(user).rayMul(lytIndexCurrent());
    }

    function lytIndexCurrent() public virtual override returns (uint256 res) {
        res = FixedPoint.max(lastLytIndex, IAavePool(pool).getReserveNormalizedIncome(underlying));
        lastLytIndex = res;
        return res;
    }

    function lytIndexStored() public view override returns (uint256 res) {
        res = lastLytIndex;
    }

    function getRewardTokens() public view override returns (address[] memory res) {
        return IAaveRewardsController(rewardsController).getRewardsByAsset(yieldToken);
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function getBaseTokens() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = underlying;
    }

    function isValidBaseToken(address token) public view virtual override returns (bool res) {
        res = (token == underlying);
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    function _redeemExternalReward() internal override {
        address[] memory assets = new address[](1);
        assets[0] = yieldToken;

        IAaveRewardsController(rewardsController).claimAllRewards(assets, address(this));
    }
}
