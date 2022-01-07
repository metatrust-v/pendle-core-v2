// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

pragma solidity 0.8.9;
pragma abicoder v2;
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

/*
   ^
f_t|        
   |\      
   | \   
   |  x
   |   \ 
   |    \
 0 +--t---+------> time

 slope = f(t) - f(t-1)
 bias = f(t)
 timestamp = t
*/

struct Line {
    uint256 slope;
    uint256 bias;
    uint256 timestamp; // currently at
    uint256 expiry;
}

library LineHelper {
    using SafeMath for uint256;

    function add(Line memory a, Line memory b) internal pure returns (Line memory res) {
        require(a.timestamp == b.timestamp, "TIMESTAMP_NOT_MATCHED");
        res.slope = a.slope.add(b.slope);
        res.bias = a.bias.add(b.bias);
        res.timestamp = a.timestamp;
        res.expiry = a.expiry;
    }

    function sub(Line memory a, Line memory b) internal pure returns (Line memory res) {
        require(a.timestamp == b.timestamp, "TIMESTAMP_NOT_MATCHED");
        res.slope = a.slope.sub(b.slope);
        res.bias = a.bias.sub(b.bias);
        res.timestamp = a.timestamp;
        res.expiry = a.expiry;
    }

    function mul(Line memory a, uint256 b) internal pure returns (Line memory res) {
        res.slope = a.slope.mul(b);
        res.bias = a.bias.mul(b);
        res.timestamp = a.timestamp;
        res.expiry = a.expiry;
    }

    function div(Line memory a, uint256 b) internal pure returns (Line memory res) {
        res.slope = a.slope.div(b);
        res.bias = a.bias.div(b);
        res.timestamp = a.timestamp;
        res.expiry = a.expiry;
    }

    function getValueAt(Line memory a, uint256 t) internal pure returns (uint256 res) {
        require(t >= a.timestamp, "INVALID_TIMESTAMP");
        if (t < a.expiry) {
            uint256 updateValue = a.slope.mul(t.sub(a.timestamp));
            if (a.bias >= updateValue) {
                res = a.bias.sub(updateValue);
            }
        }
    }

    function getLineAt(Line memory a, uint256 t) internal pure returns (Line memory res) {
        require(t >= a.timestamp, "INVALID_TIMESTAMP");
        res.slope = a.slope;
        res.bias = LineHelper.getValueAt(a, t);
        res.timestamp = t;
        res.expiry = a.expiry;
    }

    function getCurrentLine(Line memory a) internal view returns (Line memory res) {
        res = LineHelper.getLineAt(a, block.timestamp);
    }

    function getCurrentValue(Line memory a) internal view returns (uint256 res) {
        res = LineHelper.getValueAt(a, block.timestamp);
    }

    function isExpired(Line memory a) internal view returns (bool) {
        return a.expiry >= block.timestamp;
    }
}

contract XPendle {
    using SafeMath for uint256;
    using LineHelper for Line;

    struct VotedInfo {
        Line votedBalance;
        uint256 weight;
    }

    struct UserLock {
        Line balance;
        uint256 unallocatedWeight;
        address[] gauges;
        mapping(address => VotedInfo) votedInfos;
    }

    struct Gauge {
        bytes32 gaugeType;
        Line balance;
        mapping(uint256 => uint256) expiredVotes;
    }

    struct GaugeGroup {
        Line totalBalance;
        uint256 allocation;
    }

    uint256 public constant EPOCH_DURATION = 7 days;
    uint256 public constant VOTES_PRECISION = 1_000_000_000;
    uint256 public constant ALLOCATION_DENOMINATOR = 1_000_000_000;

    ERC20 public immutable pendle;
    uint256 public immutable startTime;
    mapping(address => UserLock) public locks;
    mapping(address => Gauge) public gauges;
    mapping(bytes32 => GaugeGroup) public groups;

    constructor(ERC20 _pendle, uint256 _startTime) {
        pendle = _pendle;
        startTime = _startTime;
    }

    function createNewLock(
        address forAddr,
        uint256 amount,
        uint256 expiry
    ) external {
        require(expiry >= _currentTimestamp(), "INVALID_EXPIRY");
        require(expiry.mod(EPOCH_DURATION) == startTime.mod(EPOCH_DURATION), "INVALID_EXPIRY");

        UserLock storage userLock = locks[forAddr];
        require(userLock.balance.getCurrentValue() == 0, "LOCK_EXISTED");

        delete userLock.gauges;
        userLock.unallocatedWeight = VOTES_PRECISION;

        userLock.balance.slope = amount;
        userLock.balance.bias = amount.mul(expiry.sub(_currentTimestamp()));
        userLock.balance.timestamp = _currentTimestamp();
        userLock.balance.expiry = expiry;

        pendle.transferFrom(msg.sender, address(this), amount);
    }

    function increaseLockAmount(address forAddr, uint256 amount) external {
        UserLock storage userLock = locks[forAddr];
        require(userLock.balance.getCurrentValue() > 0, "NO_LOCK");
        userLock.balance.slope = userLock.balance.slope.add(amount);
        userLock.balance.bias = userLock.balance.slope.mul(
            userLock.balance.expiry.sub(userLock.balance.timestamp)
        );

        pendle.transferFrom(msg.sender, address(this), amount);
    }

    function increaseLockDuration(uint256 duration) external {
        require(duration.mod(EPOCH_DURATION) == 0, "INVALID_DURATION");
        UserLock storage userLock = locks[msg.sender];
        require(userLock.balance.getCurrentValue() > 0, "NO_LOCK");
        userLock.balance.expiry = userLock.balance.expiry.add(duration);
        userLock.balance.bias = userLock.balance.expiry.sub(userLock.balance.timestamp).mul(
            userLock.balance.slope
        );
    }

    function withdraw(address userAddr) external {
        UserLock storage userLock = locks[userAddr];
        require(userLock.balance.expiry < _currentTimestamp(), "LOCK_UNEXPIRED");
        pendle.transfer(userAddr, userLock.balance.slope);
        userLock.balance.slope = uint256(0);
        userLock.balance.bias = uint256(0);
    }

    function vote(address gaugeAddr, uint256 weight) external {
        UserLock storage userLock = locks[msg.sender];
        require(userLock.balance.getCurrentValue() > 0, "NO_LOCK");
        VotedInfo storage votedInfo = userLock.votedInfos[gaugeAddr];
        Gauge storage gauge = gauges[gaugeAddr];

        uint256 oldExpiry = votedInfo.votedBalance.expiry;
        uint256 newExpiry = userLock.balance.expiry;

        if (votedInfo.weight > 0 && !votedInfo.votedBalance.isExpired()) {
            gauge.expiredVotes[oldExpiry] = gauge.expiredVotes[oldExpiry].sub(
                votedInfo.votedBalance.slope
            );
            userLock.unallocatedWeight = userLock.unallocatedWeight.add(votedInfo.weight);
        }

        votedInfo.votedBalance = userLock.balance.mul(weight).div(VOTES_PRECISION);
        votedInfo.weight = weight;
        userLock.unallocatedWeight = userLock.unallocatedWeight.sub(weight);
        gauge.expiredVotes[newExpiry] = gauge.expiredVotes[newExpiry].add(
            votedInfo.votedBalance.slope
        );

        _setGaugeBalance(gauge, votedInfo.votedBalance);
    }

    function balanceOf(address account) public view returns (uint256) {
        return locks[account].balance.getCurrentValue();
    }

    function _setGaugeBalance(Gauge storage gauge, Line memory newBalance) internal {
        GaugeGroup storage group = groups[gauge.gaugeType];
        group.totalBalance = group
            .totalBalance
            .getCurrentLine()
            .sub(gauge.balance.getCurrentLine())
            .add(newBalance.getCurrentLine());
        gauge.balance = newBalance.getCurrentLine();
    }

    function _currentTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }
}
