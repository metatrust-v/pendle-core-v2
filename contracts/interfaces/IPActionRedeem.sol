// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

interface IPActionRedeem {
    function redeemDueIncome(
        address user,
        address[] calldata scys,
        address[] calldata yieldTokens,
        address[] calldata /*gauges*/
    ) external;
}
