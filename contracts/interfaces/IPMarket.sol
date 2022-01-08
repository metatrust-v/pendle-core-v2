// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./IPBaseToken.sol";

interface IPMarket is IPBaseToken {
    function OT() external view returns (address);
}
