// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPLiquidYieldToken.sol";
import "../../interfaces/IPMarket.sol";

library MarketHelper {
    struct MarketStruct {
        IPMarket market;
        IPLiquidYieldToken LYT;
        IPOwnershipToken OT;
        IPYieldToken YT;
    }

    function readMarketInfo(address marketAddr) internal view returns (MarketStruct memory res) {
        IPMarket market = IPMarket(marketAddr);
        IPOwnershipToken OT = IPOwnershipToken(market.OT());
        res = MarketStruct({
            market: market,
            LYT: IPLiquidYieldToken(market.LYT()),
            OT: OT,
            YT: IPYieldToken(OT.YT())
        });
    }
}
