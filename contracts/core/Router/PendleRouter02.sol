// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./PendleRouter01.sol";
import "./PendleRouterCore.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";

contract PendleRouter02 is PendleRouter01, PendleRouterCore {
    constructor(address _marketFactory) PendleRouterCore(_marketFactory) {}

    function swapBaseTokenForExactOT(
        address baseToken,
        uint256 amountBaseToken,
        address OT,
        address OTMarket,
        uint256 amountOTOut,
        address to,
        bytes calldata data
    ) external {
        address LYT = IPOwnershipToken(OT).LYT();

        uint256 amountLYTReceived = swapExactBaseTokenForLYT(
            baseToken,
            amountBaseToken,
            LYT,
            0, // can have a minLYTOut here to make it fail earlier
            address(this),
            data
        );

        uint256 amountLYTIn = swapLYTForExactOT(to, OTMarket, amountOTOut, amountLYTReceived);
        assert(amountLYTIn == amountLYTReceived);
    }

    function swapExactOTforBaseToken(
        address OT,
        address OTMarket,
        uint256 amountOTIn,
        address baseToken,
        uint256 minAmountBaseTokenOut,
        address to,
        bytes calldata data
    ) external returns (uint256 amountBaseTokenOut) {
        address LYT = IPOwnershipToken(OT).LYT();
        uint256 amountLYTReceived = swapExactOTForLYT(address(this), OTMarket, amountOTIn, 0);
        amountBaseTokenOut = swapExactLYTforBaseToken(
            LYT,
            amountLYTReceived,
            baseToken,
            minAmountBaseTokenOut,
            to,
            data
        );
    }
}
