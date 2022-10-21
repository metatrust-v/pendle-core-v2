// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../interfaces/IPMarket.sol";

contract ImplicitSwapfeeContract {
    using Math for int256;
    using MarketMathCore for MarketState;

    constructor() {}

    function execute(
        int256 K,
        address market,
        MarketState memory prevState,
        int256 netPtToAccount
    ) external view returns (int256 netScyToAccount) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        PYIndex index = PYIndex.wrap(YT.pyIndexStored());

        for (int256 i = 0; i < K; ++i) {
            (int256 scyToAccount, ) = prevState.executeTradeCore(
                index,
                netPtToAccount / K,
                block.timestamp
            );
            netScyToAccount += scyToAccount;
        }
    }
}
