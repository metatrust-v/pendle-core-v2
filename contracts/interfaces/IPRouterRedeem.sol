// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

interface IPRouterRedeem {
    function redeemAll(
        address user,
        address[] calldata scys,
        address[] calldata yieldTokens,
        address[] calldata gauges
    ) external;

    function withdrawAll(
        address user,
        address[] calldata scys,
        address[] calldata baseTokensOut,
        address[] calldata yieldTokens,
        address[] calldata markets
    ) external;
}