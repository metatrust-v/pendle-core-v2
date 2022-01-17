// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

pragma solidity 0.8.9;
pragma abicoder v2;
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

struct Line {
    uint256 slope;
    uint256 bias;
    uint256 expiry;
}

library LineHelper {
    function add(Line memory a, Line memory b) internal pure returns (Line memory res) {
        res.slope = a.slope.add(b.slope);
        res.bias = a.bias.add(b.bias);
        res.expiry = a.expiry;
    }

    function sub(Line memory a, Line memory b) internal pure returns (Line memory res) {
        res.slope = a.slope.sub(b.slope);
        res.bias = a.bias.sub(b.bias);
        res.expiry = a.expiry;
    }

    function mul(Line memory a, uint256 b) internal pure returns (Line memory res) {
        res.slope = a.slope.mul(b);
        res.bias = a.bias.mul(b);
        res.expiry = a.expiry;
    }

    function div(Line memory a, uint256 b) internal pure returns (Line memory res) {
        res.slope = a.slope.div(b);
        res.bias = a.bias.div(b);
        res.expiry = a.expiry;
    }

    function getValueAt(Line memory a, uint256 t) internal pure returns (uint256 res) {
        if (t < a.expiry) {
            res = a.bias - a.slope.mul(t);
        }
    }

    function getCurrentValue(Line memory a) internal view returns (uint256 res) {
        res = LineHelper.getValueAt(a, block.timestamp);
    }

    function hasExpired(Line memory a) internal view returns (bool) {
        return a.expiry > block.timestamp;
    }
}

contract XPendle is Ownable {
    using LineHelper for Line;

    struct UserGaugeVote {
        Line votedBalance;
        uint256 weight;
    }

    struct UserLock {
        Line balance;
        address[] gauges;
        uint256 unallocatedWeight;
        mapping(address => VotedInfo) votedInfos;
    }
    
    struct Gauge {
        bytes32 gaugeType;
        Line balance;

        uint256 last
        mapping(uint256 => uint256) expiredVotes;
    }

    struct GaugeGroup {
        Line totalBalance;
        uint256 allocation;
    }

    struct EpochInfo {
        bool isRewarded;
        uint256 totalReward;
        mapping(address => uint256) gaugeReward;
    }

    uint256 public constant LOCK_TIME = (1 days) / 3;
    uint256 public constant EPOCH_DURATION = 7 days;
    uint256 public constant VOTES_PRECISION = 1_000_000_000;
    uint256 public constant ALLOCATION_DENOMINATOR = 1_000_000_000;

    ERC20 public immutable pendle;
    uint256 public immutable startTime;
    mapping(address => UserLock) public locks;
    mapping(address => Gauge) public gauges;
    mapping(bytes32 => GaugeGroup) public groups;
    mapping(uint256 => EpochInfo) public epochInfos;

    uint256 public pendlePerSec;
    address[] public allGauges;

    constructor(ERC20 _pendle, uint256 _startTime) {
        pendle = _pendle;
        startTime = _startTime;
    }

    function createNewLock(
        address forAddr,
        uint256 amount,
        uint256 expiry
    ) external {
        require(expiry >= block.timestamp, "INVALID_EXPIRY");
        require(expiry.mod(EPOCH_DURATION) == startTime.mod(EPOCH_DURATION), "INVALID_EXPIRY");

        UserLock storage userLock = locks[forAddr];
        require(userLock.balance.getCurrentValue() == 0, "LOCK_EXISTED");

        delete userLock.gauges;
        userLock.unallocatedWeight = VOTES_PRECISION;

        userLock.balance.slope = amount;
        userLock.balance.bias = amount.mul(expiry.sub(block.timestamp));
        userLock.balance.timestamp = block.timestamp;
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
        require(userLock.balance.expiry < block.timestamp, "LOCK_UNEXPIRED");
        pendle.transfer(userAddr, userLock.balance.slope);
        userLock.balance.slope = uint256(0);
        userLock.balance.bias = uint256(0);
    }

    //  gauges[gaugeAddr] -> gauges[gaugeAddr][currentEpoch]
    // 
    // LOCKTIME [L, R] summmerize -> fund(K PENDLE) next week -> works just like V1
    // before first txn, fund -> 

    function vote(address gaugeAddr, uint256 weight) external {
        require(
            uint256(block.timestamp).mod(EPOCH_DURATION).add(LOCK_TIME) < EPOCH_DURATION,
            "LOCK_TIME"
        );

        UserLock storage userLock = locks[msg.sender];
        require(userLock.balance.getCurrentValue() > 0, "NO_LOCK");

        VotedInfo storage votedInfo = userLock.votedInfos[gaugeAddr];
        Gauge storage gauge = gauges[gaugeAddr];
        Line memory newGaugeBal = gauge.balance.getCurrentLine();

        uint256 oldExpiry = votedInfo.votedBalance.expiry;
        uint256 newExpiry = userLock.balance.expiry;

        // Remove old vote if not expired
        if (votedInfo.weight > 0 && !votedInfo.votedBalance.hasExpired()) {
            gauge.expiredVotes[oldExpiry] = gauge.expiredVotes[oldExpiry].sub(
                votedInfo.votedBalance.slope
            );
            userLock.unallocatedWeight = userLock.unallocatedWeight.add(votedInfo.weight);
            newGaugeBal = newGaugeBal.sub(votedInfo.votedBalance.getCurrentLine());
        }

        votedInfo.votedBalance = userLock.balance.mul(weight).div(VOTES_PRECISION);
        newGaugeBal = newGaugeBal.add(votedInfo.votedBalance.getCurrentLine());

        votedInfo.weight = weight;
        userLock.unallocatedWeight = userLock.unallocatedWeight.sub(weight);

        gauge.expiredVotes[newExpiry] = gauge.expiredVotes[newExpiry].add(
            votedInfo.votedBalance.slope
        );

        _setGaugeBalance(gauge, newGaugeBal);
    }

    function balanceOf(address account) public view returns (uint256) {
        return locks[account].balance.getCurrentValue();
    }

    function setPendlePerSec(uint256 newPendlePerSec) external onlyOwner {
        pendlePerSec = newPendlePerSec;
    }

    function getCurrentEpoch() public view returns (uint256) {
        if (block.timestamp < startTime) {
            return 0;
        }
        return uint256(block.timestamp).sub(startTime).div(EPOCH_DURATION).add(1);
    }

    function summerizeLastEpoch() external onlyOwner {
        require(
            uint256(block.timestamp).mod(EPOCH_DURATION).add(LOCK_TIME) >= EPOCH_DURATION,
            "EPOCH_NOT_ENDED"
        );

        uint256 epochId = getCurrentEpoch();
        require(epochId >= 0, "NOT_STARTED");

        EpochInfo storage epoch = epochInfos[epochId];
        if (epoch.isRewarded) {
            return;
        }

        // DISTRIBUTE REWARDS FOR GAUGE
        epoch.isRewarded = true;
        epoch.totalReward = pendlePerSec.mul(EPOCH_DURATION);
        for (uint32 i = 0; i < allGauges.length; ++i) {
            address gaugeAddr = allGauges[i];
            Gauge storage gaugeInfo = gauges[gaugeAddr];
            if (gaugeInfo.balance.hasExpired()) {
                continue;
            }

            GaugeGroup memory group = groups[gaugeInfo.gaugeType];
            uint256 groupReward = epoch.totalReward.mul(group.allocation).div(
                ALLOCATION_DENOMINATOR
            );
            uint256 gaugeReward = groupReward.mul(gaugeInfo.balance.getCurrentValue()).div(
                group.totalBalance.getCurrentValue()
            );
            pendle.transfer(gaugeAddr, gaugeReward);
            epoch.gaugeReward[gaugeAddr] = gaugeReward;
        }

        // REMOVE EXPIRED LOCKS
        uint256 nextEpochStartTime = startTime.add(epochId.mul(EPOCH_DURATION));
        for (uint32 i = 0; i < allGauges.length; ++i) {
            address gaugeAddr = allGauges[i];
            Gauge storage gaugeInfo = gauges[gaugeAddr];
            if (gaugeInfo.balance.hasExpired()) {
                continue;
            }

            GaugeGroup storage group = groups[gaugeInfo.gaugeType];
            Line memory currentGaugeBal = gaugeInfo.balance.getLineAt(nextEpochStartTime);
            Line memory currentGroupBal = group.totalBalance.getLineAt(nextEpochStartTime);

            currentGroupBal = currentGroupBal.sub(currentGaugeBal);
            currentGaugeBal.slope = currentGaugeBal.slope.sub(
                gaugeInfo.expiredVotes[nextEpochStartTime]
            );
            gaugeInfo.expiredVotes[nextEpochStartTime] = 0; // EIP 1559 gas saving
            currentGroupBal = currentGroupBal.add(currentGaugeBal);

            gaugeInfo.balance = currentGaugeBal;
            group.totalBalance = currentGroupBal;
        }
    }

    function _setGaugeBalance(Gauge storage gauge, Line memory newGaugeBal) internal {
        newGaugeBal = newGaugeBal.getCurrentLine();
        GaugeGroup storage group = groups[gauge.gaugeType];
        group.totalBalance = group
            .totalBalance
            .getCurrentLine()
            .sub(gauge.balance.getCurrentLine())
            .add(newGaugeBal);
        gauge.balance = newGaugeBal;
    }
}
