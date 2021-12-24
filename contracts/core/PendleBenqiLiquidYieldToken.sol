// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;
import "./PendleLiquidYieldToken.sol";
import "../interfaces/IBenQiComptroller.sol";
import "../interfaces/IQiToken.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/math/Math.sol";

contract PendleBenqiLiquidYieldToken is PendleLiquidYieldToken {
    using FixedPoint for uint256;
    using Math for uint256;
    using SafeERC20 for IERC20;

    IBenQiComptroller public immutable comptroller;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint8 _underlyingDecimals,
        address[] memory _rewardTokens,
        address _yieldToken,
        address _comptroller
    )
        PendleLiquidYieldToken(
            _name,
            _symbol,
            __decimals,
            _underlyingDecimals,
            _rewardTokens,
            _yieldToken
        )
    {
        comptroller = IBenQiComptroller(_comptroller);
    }

    function mint(address to, uint256 amount) public override {
        IERC20(yieldToken).safeTransferFrom(msg.sender, address(this), amount);
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) public override {
        _burn(msg.sender, amount);
        IERC20(yieldToken).safeTransfer(to, amount);
    }

    function emergencyWithdraw(address to, uint256 amount) public override {
        updateUserReward(to);
        burn(to, amount);
    }

    function exchangeRateCurrent() public override returns (uint256) {
        exchangeRateStored = Math.max(
            exchangeRateStored,
            IQiToken(yieldToken).exchangeRateCurrent()
        );
        return exchangeRateStored;
    }

    function redeemReward() public override returns (uint256[] memory outAmounts) {
        updateUserReward(msg.sender);

        for (uint8 i = 0; i < rewardTokens.length; ++i) {
            outAmounts[i] = userReward[msg.sender][i].accuredReward;
            userReward[msg.sender][i].accuredReward = 0;

            globalReward[i].lastBalance -= outAmounts[i];

            if (outAmounts[i] != 0) {
                IERC20(rewardTokens[i]).safeTransfer(msg.sender, outAmounts[i]);
            }
        }
    }

    function updateGlobalReward() public override {
        uint256 totalLYT = totalSupply();

        address[] memory holders = new address[](1);
        address[] memory qiTokens = new address[](1);
        holders[0] = address(this);
        qiTokens[0] = yieldToken;
        for (uint8 i = 0; i < rewardTokens.length; ++i) {
            comptroller.claimReward(i, holders, qiTokens, false, true);
            uint256 currentRewardBalance = IERC20(rewardTokens[i]).balanceOf(address(this));

            if (totalLYT != 0) {
                globalReward[i].index += (currentRewardBalance - globalReward[i].lastBalance)
                    .divUp(totalLYT);
            }
            globalReward[i].lastBalance = currentRewardBalance;
        }
    }

    function _updateUserRewardSkipGlobal(address user) internal override {
        uint256 principle = balanceOf(user);
        for (uint8 i = 0; i < rewardTokens.length; ++i) {
            uint256 userLastIndex = userReward[user][i].lastIndex;
            if (userLastIndex == globalReward[i].index) continue;

            uint256 rewardAmountPerLYT = globalReward[i].index - userLastIndex;
            uint256 rewardFromLYT = principle.mulDown(rewardAmountPerLYT);

            userReward[user][i].accuredReward += rewardFromLYT;
            userReward[user][i].lastIndex = globalReward[i].index;
        }
    }
}
