// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
pragma abicoder v2;

interface IGaugeController {
    function getRewardIncentivized(
        address gauge,
        uint256 from,
        uint256 to
    ) external returns (uint256);
}
