// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
pragma abicoder v2;

interface IXPendle {
    function fund(uint256 epochId) external returns (uint256);
}
