// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IBoringOwnableUpgradeable {
    function transferOwnership(
        address newOwner,
        bool direct,
        bool renounce
    ) external;
}