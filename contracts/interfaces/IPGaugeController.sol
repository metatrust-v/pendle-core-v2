// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

interface IPGaugeController {
    event MarketClaimReward(address indexed market, uint256 amount);

    event ReceiveVotingResult(uint128 timestamp, address[] markets, uint256[] incentives);

    function pendle() external returns (address);

    function claimMarketReward() external;

    function rewardData(address pool)
        external
        view
        returns (
            uint128 pendlePerSec,
            uint128,
            uint128,
            uint128
        );
}
