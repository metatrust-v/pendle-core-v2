// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./PendleRouterCore.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../interfaces/IPYieldToken.sol";
import "./base/PendleRouterBase.sol";

contract PendleRouter03 is PendleRouterBase {
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
    }

    function swapLYTforYT(
        address LYT,
        uint256 amountLYTIn,
        address YT,
        uint256 minAmountYTOut,
        address to
    ) external returns (uint256 amountYTOut) {}

    function swapYTforLYT(
        address LYT,
        uint256 amountLYTIn,
        address YT,
        uint256 minAmountYTOut,
        address to
    ) external returns (uint256 amountYTOut) {}
}
