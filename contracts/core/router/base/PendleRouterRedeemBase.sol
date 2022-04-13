pragma solidity 0.8.9;

import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../misc/PendleJoeSwapHelperUpg.sol";
import "../../../SuperComposableYield/ISuperComposableYield.sol";
import "../../../interfaces/IPYieldToken.sol";
import "../../../core/PendleMarket.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/math/Math.sol";

abstract contract PendleRouterRedeemBase {
    using SafeERC20 for IERC20;

    function _redeemAll(
        address user,
        address[] memory scys,
        address[] memory yieldTokens,
        address[] memory gauges
    ) internal { 
        for (uint256 i = 0; i < scys.length; ++i) {
            ISuperComposableYield(scys[i]).redeemReward(user, user);
        }
        for (uint256 i = 0; i < yieldTokens.length; ++i) {
            IPYieldToken(yieldTokens[i]).redeemDueInterest(user);
            IPYieldToken(yieldTokens[i]).redeemDueRewards(user, user);
        }
    }

    function _withdrawMarkets(
        address user,
        address[] memory markets
    ) internal {
        for (uint256 i = 0; i < markets.length; ++i) {
            PendleMarket market = PendleMarket(markets[i]);
            uint256 lpAmount = market.balanceOf(user);
            _transferToken(address(market), user, address(market), lpAmount);
            market.removeLiquidity(user, lpAmount, abi.encode());
        }
    }

    function _transferToken(
        address tokenAddr,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (amount == 0) return;
        IERC20(tokenAddr).safeTransferFrom(from, to, amount);
    }
}
