// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IPMarketCallback {
    function callback(
        address tokenToPull,
        uint256 amountToPull,
        bytes calldata data
    ) external;
}
