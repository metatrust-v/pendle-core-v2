// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarket.sol";
import "../Base/PendleRouterBase.sol";

contract PendleRouterCore is PendleRouterBase {
    using FixedPoint for uint256;
    using FixedPoint for int256;

    constructor(address _marketFactory) PendleRouterBase(_marketFactory) {}

    function callback(
        int256 amountOTIn,
        int256 amountLYTIn,
        bytes calldata cbData
    ) external override onlycallback(msg.sender) returns (bytes memory cbRes) {
        IPMarket market = IPMarket(msg.sender);
        address payer = abi.decode(cbData, (address));
        if (amountOTIn > 0) {
            IERC20(market.OT()).transferFrom(payer, msg.sender, amountOTIn.toUint());
        } else {
            IERC20(market.LYT()).transferFrom(payer, msg.sender, amountLYTIn.toUint());
        }
        // encode nothing
        cbRes = abi.encode();
    }

    function swapExactOTForLYT(
        address receipient,
        address market,
        uint256 amountOTIn,
        uint256 minAmountLYTOut
    ) public returns (uint256 amountLYTOut) {
        (amountLYTOut, ) = IPMarket(market).swapExactOTForLYT(
            receipient,
            amountOTIn,
            abi.encode(msg.sender)
        );
        require(amountLYTOut >= minAmountLYTOut, "INSUFFICIENT_LYT_OUT");
    }

    function swapLYTForExactOT(
        address receipient,
        address market,
        uint256 amountOTOut,
        uint256 maxAmountLYTIn
    ) public returns (uint256 amountLYTIn) {
        (amountLYTIn, ) = IPMarket(market).swapLYTForExactOT(
            receipient,
            amountOTOut,
            abi.encode(msg.sender)
        );

        require(amountLYTIn <= maxAmountLYTIn, "LYT_IN_LIMIT_EXCEEDED");
    }
}
