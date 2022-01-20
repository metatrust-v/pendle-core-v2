// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./PendleRouterCore.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPLiquidYieldToken.sol";
import "../Base/PendleRouterBase.sol";
import "../../libraries/helpers/MarketHelper.sol";

contract PendleRouter03 is PendleRouterBase {
    using FixedPoint for uint256;
    using FixedPoint for int256;

    struct DataLYTforExactYT {
        address receipient;
        address orgSender;
        uint256 maxAmountLYTIn;
    }

    struct DataExactYTforLYT {
        address receipient;
        address orgSender;
        uint256 minAmountLYTOut;
    }

    enum Mode {
        LYTtoYT,
        YTtoLYT
    }

    constructor(address _marketFactory) PendleRouterBase(_marketFactory) {}

    function callback(
        int256 amountOTIn,
        int256 amountLYTIn,
        bytes calldata data
    ) external override onlycallback(msg.sender) returns (bytes memory res) {
        (Mode mode, ) = abi.decode(data, (Mode, bytes));
        if (mode == Mode.LYTtoYT) {
            res = _swapLYTForExactYT_callback(msg.sender, amountOTIn, amountLYTIn, data);
        } else if (mode == Mode.YTtoLYT) {
            res = _swapExactYTForLYT_callback(msg.sender, amountOTIn, amountLYTIn, data);
        }
    }

    function swapLYTForExactYT(
        address market,
        uint256 maxAmountLYTIn,
        uint256 amountYTOut,
        address receipient
    ) external returns (uint256 amountLYTIn) {
        (, bytes memory res) = IPMarket(market).swapLYTForExactOT(
            address(this),
            amountYTOut,
            abi.encode(
                Mode.LYTtoYT,
                DataLYTforExactYT({
                    receipient: receipient,
                    orgSender: msg.sender,
                    maxAmountLYTIn: maxAmountLYTIn
                })
            )
        );
        amountLYTIn = abi.decode(res, (uint256));
    }

    function swapExactYTForLYT(
        address market,
        uint256 amountYTIn,
        uint256 minAmountLYTOut,
        address receipient
    ) external returns (uint256 amountLYTOut) {
        // amountOTOut = amountYTIn
        (, bytes memory res) = IPMarket(market).swapLYTForExactOT(
            address(this),
            amountYTIn,
            abi.encode(
                Mode.YTtoLYT,
                DataExactYTforLYT({
                    receipient: receipient,
                    orgSender: msg.sender,
                    minAmountLYTOut: minAmountLYTOut
                })
            )
        );
        amountLYTOut = abi.decode(res, (uint256));
    }

    function _swapLYTForExactYT_callback(
        address marketAddr,
        int256 amountOTIn_raw,
        int256 amountLYTIn_raw,
        bytes calldata data_raw
    ) internal returns (bytes memory res) {
        MarketHelper.MarketStruct memory market = MarketHelper.readMarketInfo(marketAddr);

        uint256 amountOTIn = amountOTIn_raw.toUint();
        uint256 amountLYTOut = amountLYTIn_raw.neg().toUint();
        DataLYTforExactYT memory data = abi.decode(data_raw, (DataLYTforExactYT));

        uint256 totalAmountLYTNeed = amountOTIn.divDown(market.LYT.exchangeRateCurrent());
        uint256 amountLYTToPull = totalAmountLYTNeed.subMax0(amountLYTOut);
        require(amountLYTToPull <= data.maxAmountLYTIn, "INSUFFICIENT_LYT_IN");
        market.LYT.transferFrom(data.orgSender, address(this), amountLYTToPull);

        // tokenize LYT to OT + YT
        market.LYT.transfer(address(market.YT), totalAmountLYTNeed);
        uint256 amountOTRecieved = market.YT.tokenizeYield(address(this));

        // payback OT to the market
        market.OT.transfer(marketAddr, amountOTRecieved);
        // transfer YT out to user
        market.YT.transfer(data.receipient, amountOTRecieved);

        res = abi.encode(amountLYTToPull);
    }

    function _swapExactYTForLYT_callback(
        address marketAddr,
        int256,
        int256 amountLYTIn_raw,
        bytes calldata data_raw
    ) internal returns (bytes memory res) {
        MarketHelper.MarketStruct memory market = MarketHelper.readMarketInfo(marketAddr);

        uint256 amountLYTIn = amountLYTIn_raw.toUint();
        DataExactYTforLYT memory data = abi.decode(data_raw, (DataExactYTforLYT));

        market.YT.transferFrom(
            data.orgSender,
            address(market.YT),
            market.YT.balanceOf(address(this))
        );
        market.OT.transfer(address(market.YT), market.OT.balanceOf(address(this)));

        uint256 amountLYTReceived = market.YT.redeemUnderlying(address(this));
        uint256 amountLYTOutToUser = amountLYTReceived - amountLYTIn;
        require(amountLYTOutToUser >= data.minAmountLYTOut, "INSUFFICIENT_LYT_OUT");

        market.LYT.transfer(marketAddr, amountLYTIn);
        market.LYT.transfer(data.receipient, amountLYTOutToUser);

        res = abi.encode(amountLYTOutToUser);
    }
}
