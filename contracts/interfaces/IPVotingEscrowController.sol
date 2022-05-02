pragma solidity 0.8.9;
pragma abicoder v2;

interface IPVotingEscrowController {
    function pendlePerSec() external returns (uint256);

    function totalVote() external returns (uint256);

    /**
     * @return vote Amount of vePendle voted for pool
     * @return pendleSpeed Amount of Pendle incentivized for pool per second
     */
    function readPoolRewardInfo(address pool) external returns (uint256 vote, uint256 pendleSpeed);
}
