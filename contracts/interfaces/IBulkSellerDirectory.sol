// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IBulkSellerDirectory {
    function getBulkSeller(address token, address SY) external view returns (address);
}
