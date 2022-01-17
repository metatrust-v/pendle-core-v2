// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

pragma solidity 0.8.9;
pragma abicoder v2;
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IXPendle.sol";
import "../libraries/math/FixedPoint.sol";

contract LiquidityMining {
    using FixedPoint for uint256;

    // solhint-disable var-name-mixedcase
    // solhint-disable func-param-name-mixedcase

    struct GlobalReward {
        uint256 index;
        uint256 lastTimestamp;
        uint256 lastStakeBalance;
        uint32 lastRewardedEpoch;
    }

    struct UserReward {
        uint256 lastIndex;
        uint256 accuredReward;
        uint256 stakeBalance;
    }

    uint256 public constant EPOCH_DURATION = 7 days;
    uint256 private constant _INITIAL_REWARD_INDEX = 1;

    uint256 public immutable startTime;
    IXPendle public immutable XPendle;
    ERC20 public immutable pendle;
    ERC20 public immutable stakeToken;

    GlobalReward public globalReward;
    mapping(uint32 => uint256) public epochPendlePerSec;
    mapping(address => UserReward) public userReward;

    constructor(
        uint256 _startTime,
        IXPendle _XPendle,
        ERC20 _pendle,
        ERC20 _stakeToken
    ) {
        startTime = _startTime;
        XPendle = _XPendle;
        pendle = _pendle;
        stakeToken = _stakeToken;
        globalReward.index = _INITIAL_REWARD_INDEX;
    }

    modifier checkIfStarted() {
        require(block.timestamp >= startTime, "NOT_STARTED");
        _;
    }

    function stake(address user) external checkIfStarted {
        uint256 amount = stakeToken.balanceOf(address(this)).sub(globalReward.lastStakeBalance);
        _stake(user, amount);
    }

    function withdraw(
        address user,
        address to,
        uint256 amount
    ) external checkIfStarted {
        _withdraw(user, amount);
        stakeToken.transfer(to, amount);
    }

    function redeemReward(address user, address to)
        external
        checkIfStarted
        returns (uint256 amount)
    {
        require(block.timestamp >= startTime, "NOT_STARTED");

        amount = _redeemReward(user);
        if (amount > 0) {
            pendle.transfer(to, amount);
        }
    }

    function updateGlobalReward() public checkIfStarted {
        require(block.timestamp >= startTime, "NOT_STARTED");
        _redeemGlobalReward();

        uint256 lastTimestamp = _getEpochLastTimestamp();
        uint256 rewardForPeriod = epochPendlePerSec[getCurrentEpoch()] *
            (block.timestamp - lastTimestamp);

        globalReward.index = globalReward.index.add(
            rewardForPeriod.divUp(globalReward.lastStakeBalance)
        );
        globalReward.lastTimestamp = block.timestamp;
    }

    function updateUserReward(address user) public checkIfStarted {
        updateGlobalReward();
        UserReward storage userRwd = userReward[user];
        if (userRwd.lastIndex == 0) {
            userRwd.lastIndex = globalReward.index;
            return;
        }
        userRwd.accuredReward = userRwd.accuredReward.add(getDueReward(user));
        userRwd.lastIndex = globalReward.index;
    }

    function getDueReward(address user) public view returns (uint256 dueReward) {
        UserReward memory userRwd = userReward[user];
        if (userRwd.lastIndex == 0) {
            dueReward = 0;
        } else {
            dueReward = userRwd.accuredReward.add(
                userRwd.stakeBalance.mulDown(globalReward.index.sub(userRwd.lastIndex))
            );
        }
    }

    function getCurrentEpoch() public view returns (uint32) {
        if (block.timestamp < startTime) return 0;
        return uint32(1 + (block.timestamp - startTime) / EPOCH_DURATION);
    }

    function _getEpochLastTimestamp() internal view returns (uint256 lastTimestamp) {
        uint256 epochId = getCurrentEpoch();
        require(epochId > 0, "NOT_STARTED");
        lastTimestamp = startTime + (epochId - 1) * EPOCH_DURATION;
        if (lastTimestamp < globalReward.lastTimestamp) {
            lastTimestamp = globalReward.lastTimestamp;
        }
    }

    function _redeemGlobalReward() internal {
        uint32 _currentEpoch = getCurrentEpoch();
        if (_currentEpoch == globalReward.lastRewardedEpoch) {
            return;
        }
        for (uint32 i = globalReward.lastRewardedEpoch + 1; i <= _currentEpoch; i++) {
            uint256 rewardFunded = XPendle.fund(i);
            epochPendlePerSec[i] = rewardFunded / EPOCH_DURATION;
            if (i < _currentEpoch) {
                globalReward.index = globalReward.index.add(
                    rewardFunded.divUp(globalReward.lastStakeBalance)
                );
            }
        }
        globalReward.lastRewardedEpoch = _currentEpoch;
    }

    function _stake(address user, uint256 amount) internal {
        updateUserReward(user);
        userReward[user].stakeBalance = userReward[user].stakeBalance.add(amount);
        globalReward.lastStakeBalance = globalReward.lastStakeBalance.add(amount);
    }

    function _withdraw(address user, uint256 amount) internal {
        updateUserReward(user);
        userReward[user].stakeBalance = userReward[user].stakeBalance.sub(amount);
        globalReward.lastStakeBalance = globalReward.lastStakeBalance.sub(amount);
    }

    function _redeemReward(address user) internal returns (uint256 reward) {
        updateUserReward(user);
        reward = getDueReward(user);
        userReward[user].accuredReward = userReward[user].accuredReward.sub(reward);
    }
}
