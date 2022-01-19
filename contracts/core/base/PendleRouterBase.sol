// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarketCallback.sol";
import "../../libraries/math/FixedPoint.sol";

abstract contract PendleRouterBase is IPMarketCallback {
    address public immutable marketFactory;

    modifier onlycallback(address market) {
        require(IPMarketFactory(marketFactory).isValidMarket(market), "INVALID_MARKET");
        _;
    }

    constructor(address _marketFactory) {
        marketFactory = _marketFactory;
    }

    function callback(
        address tokenReceived,
        uint256 amountReceived,
        address tokenOwed,
        uint256 amountOwed,
        bytes calldata data
    ) external virtual override;
}
