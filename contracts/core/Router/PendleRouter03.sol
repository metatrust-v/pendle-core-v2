// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./PendleRouterCore.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../Base/PendleRouterBase.sol";

contract PendleRouter03 is PendleRouterBase {
    using FixedPoint for uint256;
    using FixedPoint for int256;

    constructor(address _marketFactory) PendleRouterBase(_marketFactory) {}

    function callback(
        address tokenReceived,
        uint256 amountReceived,
        address tokenOwed,
        uint256 amountOwed,
        bytes calldata data
    ) external override onlycallback(msg.sender) {}

    function swapLYTforYT(
        address market,
        address LYT,
        uint256 amountLYTIn,
        address YT,
        uint256 minAmountYTOut,
        address receipient
    ) external returns (uint256 amountYTOut) {}

    function swapExactYTforLYT(
        address market,
        address LYT,
        uint256 amountYTIn,
        address YT,
        uint256 minAmountLYTOut,
        address receipient
    ) external returns (uint256 amountLYTOut) {
        // amountOTIn = amountYTIn
        int256 amountOTIn = amountYTIn.toInt();
        int256 amountLYTIn = IPMarket(market).swap(receipient, amountOTIn, abi.encode(msg.sender));
    }
}
