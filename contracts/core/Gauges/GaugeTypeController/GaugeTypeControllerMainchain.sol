pragma solidity 0.8.9;
pragma abicoder v2;

import "../VotingController.sol";
import "./GaugeTypeControllerAbstract.sol";

contract GaugeTypeControllerMainchain is GaugeTypeControllerAbstract {
    VotingController public immutable votingController;

    constructor(
        VotingController _votingController,
        IERC20 _pendle,
        uint256 _startTime
    ) GaugeTypeControllerAbstract(_pendle, _startTime) {
        votingController = _votingController;
    }

    function setVotingResults(address[] calldata gauges, uint256[] calldata votes) external {
        require(msg.sender == address(votingController), "NOT_VOTING_CONTROLLER");
        _setVotingResults(gauges, votes);
    }
}
