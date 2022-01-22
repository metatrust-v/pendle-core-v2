// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

pragma solidity 0.8.9;
pragma abicoder v2;
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

/**
 * This contract is currently made for one chain
 */

struct Line {
    uint256 slope;
    uint256 bias;
}

library LineHelper {
    function add(Line memory a, Line memory b) internal pure returns (Line memory res) {
        res.slope = a.slope + b.slope;
        res.bias = a.bias + b.bias;
    }

    function sub(Line memory a, Line memory b) internal pure returns (Line memory res) {
        res.slope = a.slope - b.slope;
        res.bias = a.bias - b.bias;
    }

    function mul(Line memory a, uint256 b) internal pure returns (Line memory res) {
        res.slope = a.slope * b;
        res.bias = a.bias * b;
    }

    function div(Line memory a, uint256 b) internal pure returns (Line memory res) {
        res.slope = a.slope / b;
        res.bias = a.bias / b;
    }

    function getValueAt(Line memory a, uint256 t) internal pure returns (uint256 res) {
        if (a.bias >= a.slope * t) {
            res = a.bias - a.slope * t;
        }
    }

    function getCurrentBalance(Line memory a) internal view returns (uint256 res) {
        res = LineHelper.getValueAt(a, block.timestamp);
    }

    /**
        This function should be used for user line only
     */
    function getExpiry(Line memory a) internal view returns (uint256 res) {
        return a.bias / a.slope;
    }
}

contract XPendle is Ownable {
    using LineHelper for Line;
    using SafeERC20 for IERC20;


    struct UserGaugeVote {
        Line votedBalance;
        uint256 weight;
        uint256 expiry;
    }

    struct UserLock {
        Line balance;
        uint256 expiry;
        uint256 unallocatedWeight;
        mapping(address => UserGaugeVote) votedInfos;
    }

    struct Gauge {
        address gaugeAddr;
        bytes32 gaugeType;
        Line balance;
        uint256 lastTimestamp;
        mapping(uint256 => uint256) expiredVotes;
    }

    struct GaugeGroup {
        Line totalBalance;
        uint256 allocation;
    }

    uint256 public constant EPOCH_DURATION = 7 days;
    uint256 public constant VOTES_PRECISION = 1_000_000_000;

    IERC20 public immutable pendle;
    uint256 public lastPendleBalance;
    uint256 public immutable startTime;

    address[] public allGauges;
    mapping(address => Gauge) public gauges;
    mapping(address => UserLock) public locks;
    mapping(bytes32 => GaugeGroup) public groups;

    constructor(IERC20 _pendle, uint256 _startTime) {
        pendle = _pendle;
        startTime = _startTime;
    }

    function createNewLock(address forAddr, uint256 expiry) external {
        require(
            expiry >= block.timestamp && expiry % EPOCH_DURATION == startTime % EPOCH_DURATION,
            "INVALID_EXPIRY"
        );

        UserLock storage userLock = locks[forAddr];
        require(userLock.balance.getCurrentBalance() == 0, "LOCK_EXISTED");

        uint256 amount = _consumePendle();
        userLock.unallocatedWeight = VOTES_PRECISION;
        userLock.balance.slope = amount;
        userLock.balance.bias = expiry * amount;
        userLock.expiry = expiry;
    }

    function increaseLockAmount(address forAddr) external {
        UserLock storage userLock = locks[forAddr];
        require(userLock.balance.getCurrentBalance() > 0, "LOCK_NOT_EXISTED");

        uint256 amount = _consumePendle();
        userLock.balance.slope += amount;
        userLock.balance.bias += amount * userLock.expiry;
    }

    function increaseLockDuration(uint256 newExpiry) external {
        UserLock storage userLock = locks[msg.sender];
        require(userLock.balance.getCurrentBalance() > 0, "LOCK_NOT_EXISTED");
        require(
            newExpiry % EPOCH_DURATION == startTime % EPOCH_DURATION && newExpiry > userLock.expiry,
            "INVALID_EXPIRY"
        );

        userLock.expiry = newExpiry;
        userLock.balance.bias = newExpiry * userLock.balance.slope;
    }

    /**
        Maybe non-reentrant here
     */
    function withdraw(address userAddr) external {
        UserLock storage userLock = locks[userAddr];
        require(userLock.expiry < block.timestamp, "LOCK_UNEXPIRED");
        pendle.safeTransfer(userAddr, userLock.balance.slope);
        userLock.balance.slope = uint256(0);
    }

    function vote(address gaugeAddr, uint256 weight) external {
        UserLock storage userLock = locks[msg.sender];
        require(userLock.balance.getCurrentBalance() > 0, "LOCK_NOT_EXISTED");

        UserGaugeVote storage votedInfo = userLock.votedInfos[gaugeAddr];
        Gauge storage gauge = gauges[gaugeAddr];
        Line memory newGaugeBal = getLatestGaugeBalance(gaugeAddr);

        uint256 oldExpiry = votedInfo.expiry;
        uint256 newExpiry = userLock.expiry;

        // Remove old vote if not expired
        if (votedInfo.votedBalance.getCurrentBalance() > 0) {
            gauge.expiredVotes[oldExpiry] =
                gauge.expiredVotes[oldExpiry] -
                votedInfo.votedBalance.slope;
            userLock.unallocatedWeight = userLock.unallocatedWeight + votedInfo.weight;
            newGaugeBal = newGaugeBal.sub(votedInfo.votedBalance);
        }

        votedInfo.weight = weight;
        userLock.unallocatedWeight = userLock.unallocatedWeight - weight;
        votedInfo.votedBalance = userLock.balance.mul(weight).div(VOTES_PRECISION);

        newGaugeBal = newGaugeBal.add(votedInfo.votedBalance);
        gauge.expiredVotes[newExpiry] =
            gauge.expiredVotes[newExpiry] +
            votedInfo.votedBalance.slope;

        _updateGaugeBalance(gauge, newGaugeBal);
    }

    function balanceOf(address account) public view returns (uint256) {
        return locks[account].balance.getCurrentBalance();
    }

    function _updateGaugeBalance(Gauge storage gauge, Line memory newGaugeBal) internal {
        GaugeGroup storage group = groups[gauge.gaugeType];
        group.totalBalance = group.totalBalance.sub(gauge.balance).add(newGaugeBal);
        gauge.balance = newGaugeBal;
        gauge.lastTimestamp = block.timestamp / EPOCH_DURATION * EPOCH_DURATION;
    }

    function getLatestGaugeBalance(address gaugeAddr) public view returns (Line memory gaugeBalance) {
        uint256 lastTimestamp = gauges[gaugeAddr].lastTimestamp;
        gaugeBalance = gauges[gaugeAddr].balance;

        while(lastTimestamp + EPOCH_DURATION <= block.timestamp) {
            lastTimestamp += EPOCH_DURATION;
            uint256 slopeDelta = gauges[gaugeAddr].expiredVotes[lastTimestamp];
            gaugeBalance.bias -= lastTimestamp * slopeDelta;
            gaugeBalance.slope -= slopeDelta;
        }
    }

    function _consumePendle() internal returns (uint256 amount) {
        uint256 currentBal = pendle.balanceOf(address(this));
        amount = currentBal - lastPendleBalance;
        lastPendleBalance = currentBal;
    }
}
