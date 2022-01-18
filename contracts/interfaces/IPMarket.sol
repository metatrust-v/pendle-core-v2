// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./IPBaseToken.sol";

interface IPMarket is IPBaseToken {
    function OT() external view returns (address);

    function swap(
        address recipient,
        int256 amountOTIn,
        bytes calldata data
    ) external returns (int256 amountLYTIn);

    function getAmountOTOutFromLYT(uint256 amountLYTIn)
        external
        pure
        returns (uint256 amountOTOut);
}
