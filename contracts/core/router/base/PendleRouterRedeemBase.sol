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

    function _withdrawAll(
        address user,
        address[] memory scys,
        address[] memory baseTokensOut,
        address[] memory yieldTokens,
        address[] memory markets
    ) internal {
        require(scys.length == baseTokensOut.length, "invalid scy data");
        _redeemAll(user, scys, yieldTokens, new address[](0));

        for (uint256 i = 0; i < markets.length; ++i) {
            PendleMarket market = PendleMarket(markets[i]);
            uint256 lpAmount = market.balanceOf(user);
            _transferToken(address(market), user, address(market), lpAmount);
            market.removeLiquidity(user, lpAmount, abi.encode());
        }

        for (uint256 i = 0; i < yieldTokens.length; ++i) {
            IPYieldToken yt = IPYieldToken(yieldTokens[i]);
            IERC20 ot = IERC20(yt.OT());

            uint256 yoAmount = ot.balanceOf(user);
            if (!yt.isExpired()) {
                yoAmount = Math.min(yoAmount, yt.balanceOf(user));
                _transferToken(address(yt), user, address(yt), yoAmount);
            }
            _transferToken(address(ot), user, address(yt), yoAmount);
            yt.redeemYO(user);
        }

        for (uint256 i = 0; i < scys.length; ++i) {
            ISuperComposableYield scy = ISuperComposableYield(scys[i]);
            uint256 scyAmount = scy.balanceOf(user);
            _transferToken(address(scy), user, address(scy), scyAmount);
            scy.redeem(user, baseTokensOut[i], 0);
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
