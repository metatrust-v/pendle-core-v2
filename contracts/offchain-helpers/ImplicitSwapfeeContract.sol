// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../interfaces/IPMarket.sol";

contract ImplicitSwapfeeContract {
    using Math for int256;
    using MarketMathCore for MarketState;

    int256 public constant K = 100;
    
    constructor() {}

    function execute(
        address market,
        MarketState memory prevState,
        int256 netPtToAccount
    ) external view returns (int256 netScyToAccount) {
        (,, IPYieldToken YT) = IPMarket(market).readTokens();
        PYIndex index = PYIndex.wrap(YT.pyIndexStored());

        // console.log(netPtToAccount.Uint());
        console.log("At first, there are ", prevState.totalPt.Uint());

        for(int256 i = 0; i < K; ++i) {
            console.log("Trade no ", i.Uint(), "-th");
            (int256 scyToAccount, ) = prevState.executeTradeCore(index, netPtToAccount / K, block.timestamp);

            netScyToAccount += scyToAccount;

            console.log(scyToAccount.Uint(), prevState.totalPt.Uint());
        }
    }
}
