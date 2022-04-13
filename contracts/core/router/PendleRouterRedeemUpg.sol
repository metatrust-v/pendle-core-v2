// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./base/PendleRouterRedeemBase.sol";
import "../../interfaces/IPRouterRedeem.sol";

contract PendleRouterRedeemUpg is
    IPRouterRedeem,
    PendleRouterRedeemBase
{
    function redeemAll(
        address user,
        address[] calldata scys,
        address[] calldata yieldTokens,
        address[] calldata gauges
    ) external {
        _redeemAll(user, scys, yieldTokens, gauges);
    }

    function withdrawMarkets(
        address user,
        address[] calldata markets
    ) external {
        _withdrawMarkets(user, markets);
    }
}
