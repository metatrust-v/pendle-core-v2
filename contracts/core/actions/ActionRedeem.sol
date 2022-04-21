// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./base/ActionRedeemBase.sol";
import "../../interfaces/IPActionRedeem.sol";

contract PendleRouterRedeemUpg is IPActionRedeem, ActionRedeemBase {
    function redeemDueIncome(
        address[] calldata scys,
        address[] calldata yieldTokens,
        address[] calldata gauges
    ) external {
        _redeemDueIncome(scys, yieldTokens, gauges);
    }

    function withdrawMarkets(address[] calldata markets) external {
        _withdrawMarkets(markets);
    }
}
