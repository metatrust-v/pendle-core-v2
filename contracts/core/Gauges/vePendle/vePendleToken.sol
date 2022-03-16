// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.9;
pragma abicoder v2;
import "../EpochController.sol";
import "../../../libraries/Linebrary.sol";
import "../../../interfaces/IVEPendleToken.sol";

abstract contract vePendleToken is IVEPendleToken, EpochController {
    using LineHelper for Line;

    struct Checkpoint {
        Line value;
        uint256 timestamp;
    }

    mapping(address => Line) public userLock;

    Line public supply;
    uint256 public lastEpoch;
    mapping(uint256 => uint256) public expiredVotes;

    Checkpoint[] public supplyCheckpoints;
    mapping(address => Checkpoint[]) public userCheckpoints;

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
        userCheckpoints[user].push(Checkpoint(newLine, block.timestamp));
        supplyCheckpoints.push(Checkpoint(supply, block.timestamp));
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

    function getCheckpointAt(Checkpoint[] memory checkpoints, uint256 timestamp)
        public
        pure
        returns (Checkpoint memory)
    {
        if (checkpoints.length == 0 || checkpoints[0].timestamp > timestamp) {
            return Checkpoint(Line(0, 0), 0);
        }
        uint256 l = 0;
        uint256 r = checkpoints.length - 1;
        while (l < r) {
            uint256 mid = (l + r) / 2;
            if (checkpoints[mid].timestamp <= timestamp) {
                l = mid;
            } else {
                r = mid - 1;
            }
        }
        return checkpoints[l];
    }

    function getUserBalanceAt(address user, uint256 timestamp) public view returns (uint256) {
        return getCheckpointAt(userCheckpoints[user], timestamp).value.getValueAt(timestamp);
    }

    function getSupplyAt(uint256 timestamp) public view returns (uint256) {
        Checkpoint memory checkpoint = getCheckpointAt(supplyCheckpoints, timestamp);
        for (
            uint256 i = getEpochEndingTimestamp(getEpochId(checkpoint.timestamp));
            i < timestamp;
            i += EPOCH_DURATION
        ) {
            uint256 slope = expiredVotes[i];
            checkpoint.value = checkpoint.value.sub(Line(slope, slope * i));
        }
        return checkpoint.value.getValueAt(timestamp);
    }
}
