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

    constructor(IERC20 _pendle, uint256 _startTime) EpochController(_startTime) {
        pendle = _pendle;
    }

    mapping(address => bool) public isGaugeValid;
    mapping(address => mapping(uint256 => uint256)) public gaugeEpochIncentives;

    function setGaugeValidity(address gauge, bool validity) external onlyOwner {
        isGaugeValid[gauge] = validity;
        pendle.approve(gauge, validity ? type(uint256).max : 0);
    }

    function setPendlePerSec(uint256 newPendlePerSec) external onlyOwner {
        pendlePerSec = newPendlePerSec;
    }

    function _setVotingResults(address[] memory gauges, uint256[] memory votes) internal {
        require(gauges.length == votes.length, "INVALID_VOTING_RESULTS");
        uint256 currentEpoch = getEpochId(block.timestamp);
        uint256 totalVotes = 0;
        for (uint256 i = 0; i < votes.length; ++i) {
            totalVotes += votes[i];
        }
        for (uint256 i = 0; i < gauges.length; ++i) {
            gaugeEpochIncentives[gauges[i]][currentEpoch] = (pendlePerSec * votes[i]) / totalVotes;
        }
    }

    function getRewardIncentivized(
        address gauge,
        uint256 from,
        uint256 to
    ) public view returns (uint256) {
        if (to < startTime) return 0;
        from = Math.max(from, startTime);
        uint256 totalReward = 0;
        uint256 startEpoch = getEpochId(from);
        uint256 endEpoch = getEpochId(to);
        for (uint256 epoch = startEpoch; epoch <= endEpoch; ++epoch) {
            uint256 l = Math.max(getEpochStartingTimestamp(epoch), from);
            uint256 r = Math.min(getEpochEndingTimestamp(epoch), to);
            totalReward += gaugeEpochIncentives[gauge][epoch] * (r - l);
        }
        return totalReward;
    }
}
