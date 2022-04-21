pragma solidity 0.8.9;

import "../../../SuperComposableYield/ISuperComposableYield.sol";
import "../../../interfaces/IPYieldToken.sol";
import "../../../core/PendleMarket.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ActionRedeemBase {
    using SafeERC20 for IERC20;

    function _redeemDueIncome(
        address[] memory scys,
        address[] memory yieldTokens,
        address[] memory gauges
    ) internal {
        address user = msg.sender;
        for (uint256 i = 0; i < scys.length; ++i) {
            ISuperComposableYield(scys[i]).redeemReward(user);
        }
        for (uint256 i = 0; i < yieldTokens.length; ++i) {
            IPYieldToken(yieldTokens[i]).redeemDueInterest(user);
            IPYieldToken(yieldTokens[i]).redeemDueRewards(user);
        }
    }

    function _withdrawMarkets(address[] memory markets) internal {
        address user = msg.sender;
        for (uint256 i = 0; i < markets.length; ++i) {
            PendleMarket market = PendleMarket(markets[i]);
            uint256 lpAmount = market.balanceOf(user);
            IERC20(market).safeTransferFrom(user, address(market), lpAmount);
            market.removeLiquidity(user, lpAmount, abi.encode());
        }
    }
}
