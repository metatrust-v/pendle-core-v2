// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IPMarketCallback {
    function callback(
        address tokenReceived,
        uint256 amountReceived,
        address tokenOwed,
        uint256 amountOwed,
        bytes calldata data
    ) external;
}
