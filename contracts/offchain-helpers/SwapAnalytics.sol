// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../libraries/math/MarketMathCore.sol";
import "../interfaces/ISuperComposableYield.sol";
import "../interfaces/IPMarket.sol";

contract SwapAnalytics {
    int256 public constant K = 100;

    function getImplicitSwapAmount(
        IPMarket market,
        MarketState memory state,
        int256 netPtToAccount
    ) external view returns (int256 totalScyToAccount) {
        (ISuperComposableYield SCY, , ) = market.readTokens();

        PYIndex index = PYIndex.wrap(SCY.exchangeRate());
        for (int256 i = 0; i < K; ++i) {
            (int256 scyToAccount, ) = MarketMathCore.executeTradeCore(
                state,
                index,
                netPtToAccount / K,
                block.timestamp
            );
            totalScyToAccount += scyToAccount;
        }
    }
}
