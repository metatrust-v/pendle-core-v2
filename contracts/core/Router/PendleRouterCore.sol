// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../PendleMarket.sol";
import "../../interfaces/IPMarketFactory.sol";
import "../Base/PendleRouterBase.sol";

contract PendleRouterCore is PendleRouterBase {
    using FixedPoint for uint256;
    using FixedPoint for int256;

    constructor(address _vault, address _marketFactory) PendleRouterBase(_vault, _marketFactory) {}

    function callback(
        address tokenToPull,
        uint256 amountToPull,
        bytes calldata data
    ) external override onlycallback(msg.sender) {
        address payer = abi.decode(data, (address));

        IERC20(tokenToPull).transferFrom(payer, address(vault), amountToPull);
        IPVault(vault).depositNoTransfer(msg.sender, tokenToPull, amountToPull);
    }

    function swapOTforLYT(
        address receipient,
        address market,
        uint256 amountOTtoSell,
        uint256 minAmountLYTOut
    ) public returns (uint256 amountLYTOut) {
        amountLYTOut = PendleMarket(market)
            .swap(receipient, amountOTtoSell.toInt(), abi.encode(msg.sender))
            .neg()
            .toUint();
        require(amountLYTOut >= minAmountLYTOut, "INSUFFICIENT_LYT_OUT");
    }

    function swapLYTforOT(
        address receipient,
        address market,
        uint256 amountOTtoBuy,
        uint256 maxAmountLYTIn
    ) public returns (uint256 amountLYTIn) {
        amountLYTIn = (
            IPMarket(market).swap(receipient, amountOTtoBuy.toInt().neg(), abi.encode(msg.sender))
        ).toUint();

        require(amountLYTIn <= maxAmountLYTIn, "LYT_IN_LIMIT_EXCEEDED");
    }
}
