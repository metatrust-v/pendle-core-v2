// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./libraries/TokenHelper.sol";
import "./libraries/math/Math.sol";
import "./libraries/Errors.sol";
import "./libraries/BoringOwnableUpgradeable.sol";
import "./BulkSellerMathCore.sol";
import "../interfaces/IStandardizedYield.sol";
import "../interfaces/IBulkSeller.sol";
import "../interfaces/IBulkSellerDirectory.sol";

contract BulkSellerDirectory is IBulkSellerDirectory, BoringOwnableUpgradeable {
    mapping(address => mapping(address => address)) internal syToBulkSeller;

    constructor() initializer {
        __BoringOwnable_init();
    }

    function setBulkSeller(address bulkSeller, bool force) external onlyOwner {
        address token = IBulkSeller(bulkSeller).token();
        address SY = IBulkSeller(bulkSeller).SY();

        if (force) {
            syToBulkSeller[token][SY] = bulkSeller;
        } else {
            require(syToBulkSeller[token][SY] == address(0), "bulk seller already exists");
            syToBulkSeller[token][SY] = bulkSeller;
        }
    }

    function getBulkSeller(address token, address SY) external view override returns (address) {
        return syToBulkSeller[token][SY];
    }
}
