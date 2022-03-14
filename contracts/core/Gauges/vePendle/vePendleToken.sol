pragma solidity 0.8.9;
pragma abicoder v2;
import "../EpochController.sol";
import "../../../libraries/Linebrary.sol";
import "../../../interfaces/IVEPendleToken.sol";

abstract contract vePendleToken is IVEPendleToken, EpochController {
    using LineHelper for Line;

    mapping(address => Line) public userLock;

    Line public supply;
    uint256 public lastEpoch;
    mapping(uint256 => uint256) public expiredVotes;

    function balanceOf(address user) public view returns (uint256) {
        return userLock[user].getCurrentBalance();
    }

    function _afterSetBalance(address user) internal virtual {}

    function _setUserBalance(address user, Line memory newLine) internal {
        _updateSupply();
        Line memory oldLine = userLock[user];
        expiredVotes[oldLine.getExpiry()] -= oldLine.slope;
        expiredVotes[newLine.getExpiry()] += newLine.slope;
        userLock[user] = newLine;
        supply = supply.sub(oldLine).add(newLine);
        _afterSetBalance(user);
    }

    function totalSupply() public returns (uint256) {
        _updateSupply();
        return supply.getCurrentBalance();
    }

    function _updateSupply() internal {
        uint256 nextEpochEnd = getEpochEndingTimestamp(lastEpoch + 1);
        for (uint256 t = nextEpochEnd; t < block.timestamp; t += EPOCH_DURATION) {
            uint256 expiredSlope = expiredVotes[t];
            supply = supply.sub(Line(expiredSlope, expiredSlope * t));
            lastEpoch += 1;
        }
    }
}
