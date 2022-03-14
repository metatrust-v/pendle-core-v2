pragma solidity 0.8.9;
pragma abicoder v2;

contract EpochController {
    uint256 public immutable startTime;
    uint256 public constant EPOCH_DURATION = 7 days;

    constructor(uint256 _startTime) {
        startTime = _startTime;
    }

    function getEpochId(uint256 timestamp) public view returns (uint256) {
        require(timestamp >= startTime, "INVALID_TIMESTAMP");
        return (timestamp - startTime) / EPOCH_DURATION + 1;
    }

    function getEpochEndingTimestamp(uint256 epochId) public view returns (uint256) {
        require(epochId > 0, "INVALID_EPOCH_ID");
        return startTime + epochId * EPOCH_DURATION;
    }

    function getEpochStartingTimestamp(uint256 epochId) public view returns (uint256) {
        require(epochId > 0, "INVALID_EPOCH_ID");
        return startTime + (epochId - 1) * EPOCH_DURATION;
    }
}
