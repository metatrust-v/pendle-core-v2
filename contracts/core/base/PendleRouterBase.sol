// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarketCallback.sol";
import "../../libraries/math/FixedPoint.sol";

abstract contract PendleRouterBase is IPMarketCallback {
    address public immutable vault;
    address public immutable marketFactory;

    modifier onlycallback(address market) {
        require(IPMarketFactory(marketFactory).isValidOTMarket(market), "INVALID_MARKET");
        _;
    }

    constructor(address _vault, address _marketFactory) {
        vault = _vault;
        marketFactory = _marketFactory;
    }

    function callback(
        address tokenToPull,
        uint256 amountToPull,
        bytes calldata data
    ) external virtual override;
}
