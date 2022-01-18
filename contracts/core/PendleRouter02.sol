// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./PendleRouter01.sol";
import "./PendleRouterCore.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../interfaces/IPYieldToken.sol";

contract PendleRouter02 is PendleRouter01, PendleRouterCore {
    constructor(address _vault, address _marketFactory) PendleRouterCore(_vault, _marketFactory) {}

    function swapBaseTokenforOT(
        address baseToken,
        uint256 amountBaseToken,
        address OT,
        address OTMarket,
        uint256 minAmountOTOut,
        address to,
        bytes calldata data
    ) external returns (uint256 amountOTOut) {
        address LYT = IPOwnershipToken(OT).LYT();

        uint256 amountLYTReceived = swapBaseTokenforLYT(
            baseToken,
            amountBaseToken,
            LYT,
            0, // can have a minLYTOut here to make it fail earlier
            address(this),
            data
        );

        amountOTOut = IPMarket(OTMarket).getAmountOTOutFromLYT(amountLYTReceived);
        require(amountOTOut >= minAmountOTOut, "INSUFFICIENT_OUT_AMOUNT");

        uint256 amountLYTIn = swapLYTforOT(to, OTMarket, amountOTOut, amountLYTReceived);
        assert(amountLYTIn == amountLYTReceived);
    }

    function swapOTforBaseToken(
        address OT,
        address OTMarket,
        uint256 amountOTIn,
        address baseToken,
        uint256 minAmountBaseTokenOut,
        address to,
        bytes calldata data
    ) external returns (uint256 amountBaseTokenOut) {
        address LYT = IPOwnershipToken(OT).LYT();
        uint256 amountLYTReceived = swapOTforLYT(address(this), OTMarket, amountOTIn, 0);
        amountBaseTokenOut = swapLYTforBaseToken(
            LYT,
            amountLYTReceived,
            baseToken,
            minAmountBaseTokenOut,
            to,
            data
        );
    }
}
