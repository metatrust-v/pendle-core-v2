// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./libraries/TokenHelper.sol";
import "./libraries/math/Math.sol";
import "./libraries/Errors.sol";

contract BulkSellerSY is TokenHelper {
    using Math for uint256;

    uint256 public tokenToSyRate;
    uint256 public syToTokenRate; // tokenToSyRate * 1.01?

    uint256 public lastBalanceSy;
    uint256 public lastBalanceToken;

    address public token;
    address public sy;

    function swapExactTokenIn(address receiver) external returns (uint256 netSyOut) {
        uint256 netTokenIn = _selfBalance(token) - lastBalanceToken;

        netSyOut = netTokenIn.mulDown(tokenToSyRate);
        _transferOut(sy, receiver, netSyOut);
    }
}
