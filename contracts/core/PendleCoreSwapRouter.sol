// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./PendleMarket.sol";
import "../interfaces/IPMarketFactory.sol";

contract PendleCoreSwapRouter is IPCoreSwapRouter {
    using FixedPoint for uint256;
    using FixedPoint for int256;

    address public immutable vault;
    address public immutable marketFactory;

    modifier onlyMarketCallback(address market) {
        require(IPMarketFactory(marketFactory).isValidOTMarket(market), "INVALID_MARKET");
        _;
    }

    constructor(address _vault, address _marketFactory) {
        vault = _vault;
        marketFactory = _marketFactory;
    }

    function sellOT(
        address receipient,
        address market,
        uint256 amountOTtoSell,
        uint256 minAmountLYTOut
    ) external returns (uint256 amountLYTOut) {
        amountLYTOut = PendleMarket(market)
            .swap(receipient, amountOTtoSell.toInt(), abi.encode(msg.sender))
            .neg()
            .toUint();
        require(amountLYTOut >= minAmountLYTOut, "INSUFFICIENT_LYT_OUT");
    }

    function buyOT(
        address receipient,
        address market,
        uint256 amountOTtoBuy,
        uint256 maxAmountLYTIn
    ) external returns (uint256 amountLYTIn) {
        amountLYTIn = (
            PendleMarket(market).swap(
                receipient,
                amountOTtoBuy.toInt().neg(),
                abi.encode(msg.sender)
            )
        ).toUint();

        require(amountLYTIn <= maxAmountLYTIn, "LYT_IN_LIMIT_EXCEEDED");
    }

    function marketCallback(
        address tokenToPull,
        uint256 amountToPull,
        bytes calldata data
    ) external override onlyMarketCallback(msg.sender) {
        address payer = abi.decode(data, (address));

        IERC20(tokenToPull).transferFrom(payer, address(vault), amountToPull);
        IPVault(vault).depositNoTransfer(msg.sender, tokenToPull, amountToPull);
    }
}
