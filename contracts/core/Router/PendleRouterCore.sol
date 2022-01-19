// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../PendleMarket.sol";
import "../../interfaces/IPMarketFactory.sol";
import "../Base/PendleRouterBase.sol";

contract PendleRouterCore is PendleRouterBase {
    using FixedPoint for uint256;
    using FixedPoint for int256;

    constructor(address _marketFactory) PendleRouterBase(_marketFactory) {}

    function callback(
        address,
        uint256,
        address tokenOwed,
        uint256 amountOwed,
        bytes calldata data
    ) external override onlycallback(msg.sender) {
        // can use tokenReceived & amountReceived to fail sooner
        address payer = abi.decode(data, (address));

        IERC20(tokenOwed).transferFrom(payer, msg.sender, amountOwed);
    }

    function swapExactOTForLYT(
        address receipient,
        address market,
        uint256 amountOTIn,
        uint256 minAmountLYTOut
    ) public returns (uint256 amountLYTOut) {
        amountLYTOut = PendleMarket(market)
            .swap(receipient, amountOTIn.toInt(), abi.encode(msg.sender))
            .neg()
            .toUint();
        require(amountLYTOut >= minAmountLYTOut, "INSUFFICIENT_LYT_OUT");
    }

    function swapLYTForExactOT(
        address receipient,
        address market,
        uint256 amountOTOut,
        uint256 maxAmountLYTIn
    ) public returns (uint256 amountLYTIn) {
        amountLYTIn = (
            IPMarket(market).swap(receipient, amountOTOut.toInt().neg(), abi.encode(msg.sender))
        ).toUint();

        require(amountLYTIn <= maxAmountLYTIn, "LYT_IN_LIMIT_EXCEEDED");
    }
}
