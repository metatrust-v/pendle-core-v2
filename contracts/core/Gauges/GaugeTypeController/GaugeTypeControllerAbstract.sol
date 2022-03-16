// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
pragma abicoder v2;
import "../EpochController.sol";
import "../../../libraries/math/FixedPoint.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";

library Math {
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

contract GaugeTypeControllerAbstract is Ownable, EpochController {
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;

    IERC20 public immutable pendle;
    uint256 public pendlePerSec;

    uint256 public globalRewardIndex;
    uint256 public lastTimestamp;
    uint256 public totalVePendleVoted;

    // mapping[gauge]
    mapping(address => uint256) public accumulatedReward;
    mapping(address => uint256) public votesForGauge;
    mapping(address => uint256) public gaugeRewardIndex;

    constructor(IERC20 _pendle, uint256 _startTime) EpochController(_startTime) {
        pendle = _pendle;
        lastTimestamp = startTime;
    }

    function setGaugeValidity(address gauge, bool validity) external onlyOwner {
        pendle.approve(gauge, validity ? type(uint256).max : 0);
    }

    function setPendlePerSec(uint256 newPendlePerSec) external onlyOwner {
        pendlePerSec = newPendlePerSec;
    }

    function _setVotingResults(address[] memory gauges, uint256[] memory votes) internal {
        require(gauges.length == votes.length, "INVALID_VOTING_RESULTS");
        _updateGlobalReward();
        for (uint256 i = 0; i < gauges.length; ++i) {
            _setSingleVotingResult(gauges[i], votes[i]);
        }
    }

    function _setSingleVotingResult(address gauge, uint256 vote) internal {
        accumulatedReward[gauge] += votesForGauge[gauge].mulDown(
            globalRewardIndex - gaugeRewardIndex[gauge]
        );
        gaugeRewardIndex[gauge] = globalRewardIndex;
        totalVePendleVoted = totalVePendleVoted + vote - votesForGauge[gauge];
        votesForGauge[gauge] = vote;
    }

    function _updateGlobalReward() internal {
        if (totalVePendleVoted == 0 || block.timestamp < startTime) return;
        assert(block.timestamp <= lastTimestamp);
        globalRewardIndex += ((lastTimestamp - block.timestamp) * pendlePerSec).divUp(
            totalVePendleVoted
        );
        lastTimestamp = block.timestamp;
    }
}
