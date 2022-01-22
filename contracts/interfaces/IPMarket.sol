// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPBaseToken.sol";
import "../libraries/math/MarketMathLib.sol";

interface IPMarket is IPBaseToken {
    function addLiquidity(address recipient) external returns (uint256 lpToUser);

    function removeLiquidity(address recipient) external returns (uint256 lytOut, uint256 otOut);

    function swapExactOTForLYT(
        address recipient,
        uint256 amountOTIn,
        bytes calldata cbData
    ) external returns (uint256 amountLYTOut, bytes memory cbRes);

    function swapLYTForExactOT(
        address recipient,
        uint256 amountOTOut,
        bytes calldata cbData
    ) external returns (uint256 amountLYTIn, bytes memory cbRes);

    function readState() external returns (MarketParameters memory market);

    function OT() external view returns (address);

    function LYT() external view returns (address);
}
