// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPBaseToken.sol";

interface IPMarket is IPBaseToken {
    function swapExactOTForLYT(
        address receipient,
        uint256 amountOTIn,
        bytes calldata cbData
    ) external returns (uint256 amountLYTOut, bytes memory cbRes);

    function swapLYTForExactOT(
        address receipient,
        uint256 amountOTOut,
        bytes calldata cbData
    ) external returns (uint256 amountLYTIn, bytes memory cbRes);

    function OT() external view returns (address);

    function LYT() external view returns (address);

    // function getAmountOTOutFromLYT(uint256 amountLYTIn)
    //     external
    //     pure
    //     returns (uint256 amountOTOut);
}
