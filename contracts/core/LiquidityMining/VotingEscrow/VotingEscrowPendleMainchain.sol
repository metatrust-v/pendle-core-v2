// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;
import "../../../interfaces/IPVotingEscrowMainchain.sol";
import "../../../libraries/helpers/MiniHelpers.sol";
import "./VotingEscrowTokenBase.sol";
import "../CrossChainMsg/PendleMsgSenderAppUpg.sol";
import "../../../libraries/VeHistoryLib.sol";
import "../../../libraries/Errors.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract VotingEscrowPendleMainchain is
    VotingEscrowTokenBase,
    IPVotingEscrowMainchain,
    PendleMsgSenderAppUpg
{
    using SafeERC20 for IERC20;
    using VeBalanceLib for VeBalance;
    using VeBalanceLib for LockedPosition;
    using Checkpoints for Checkpoints.History;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    bytes private constant EMPTY_BYTES = abi.encode();
    bytes private constant SAMPLE_SUPPLY_UPDATE_MESSAGE =
        abi.encode(0, VeBalance(0, 0), EMPTY_BYTES);
    bytes private constant SAMPLE_POSITION_UPDATE_MESSAGE =
        abi.encode(0, VeBalance(0, 0), abi.encode(address(0), LockedPosition(0, 0)));

    IERC20 public immutable pendle;

    // [wTime] => slopeChanges
    mapping(uint128 => uint128) public slopeChanges;

    // Saving totalSupply checkpoint for each week, later can be used for reward accounting
    // [wTime] => totalSupply
    mapping(uint128 => uint128) public totalSupplyAt;

    // Saving VeBalance checkpoint for users of each week, can later use binary search
    // to ask for their vePendle balance at any wTime
    mapping(address => Checkpoints.History) internal userHistory;

    constructor(IERC20 _pendle, address _pendleMsgSendEndpoint)
        initializer
        PendleMsgSenderAppUpg(_pendleMsgSendEndpoint)
    {
        pendle = _pendle;
        __BoringOwnable_init();
    }

    /// @notice basically a proxy function to call increaseLockPosition & broadcastUserPosition at the same time
    function increaseLockPositionAndBroadcast(
        uint128 additionalAmountToLock,
        uint128 newExpiry,
        uint256[] calldata chainIds
    ) external payable refundUnusedEth returns (uint128 newVeBalance) {
        newVeBalance = increaseLockPosition(additionalAmountToLock, newExpiry);
        broadcastUserPosition(msg.sender, chainIds);
    }

    /**
     * @notice increase the lock position of an user. Applicable even when user has no position or the
        current position has expired
     * @dev expected state changes:
        - a new lock with amount = amountToPull + amountExpired, expiry = expiry is created for msg.sender in positionData
        - pendle is taken in if necessary
        - _totalSupply, lastSlopeChangeAppliedAt, slopeChanges, totalSupplyAt is updated
        - a checkpoint is added
     * @dev broadcast is not bundled since it can be done anytime after
     */
    function increaseLockPosition(uint128 additionalAmountToLock, uint128 newExpiry)
        public
        returns (uint128 newVeBalance)
    {
        address user = msg.sender;

        if (!WeekMath.isValidWTime(newExpiry)) revert Errors.InvalidWTime(newExpiry);
        if (MiniHelpers.isTimeInThePast(newExpiry)) revert Errors.ExpiryInThePast(newExpiry);

        if (newExpiry < positionData[user].expiry) revert Errors.VENotAllowedReduceExpiry();

        if (newExpiry > block.timestamp + MAX_LOCK_TIME) revert Errors.VEExceededMaxLockTime();
        if (newExpiry < block.timestamp + MIN_LOCK_TIME) revert Errors.VEInsufficientLockTime();

        uint128 newTotalAmountLocked = additionalAmountToLock + positionData[user].amount;
        if (newTotalAmountLocked == 0) revert Errors.VEZeroAmountLocked();

        uint128 additionalDurationToLock = newExpiry - positionData[user].expiry;

        if (additionalAmountToLock > 0) {
            pendle.safeTransferFrom(user, address(this), additionalAmountToLock);
        }

        newVeBalance = _increasePosition(user, additionalAmountToLock, additionalDurationToLock);

        emit NewLockPosition(user, newTotalAmountLocked, newExpiry);
    }

    /**
     * @notice withdraw an expired lock position, get back all locked PENDLE
     * @dev expected state changes:
        - positionData is cleared
        - pendle is transferred out
        - _totalSupply, lastSlopeChangeAppliedAt, slopeChanges, totalSupplyAt all doesn't need to be updated
            since these data will automatically hold true when _applySlopeChange() is called
        - no checkpoint is added
     * @dev broadcast is not bundled since it can be done anytime after
     */
    function withdraw() external returns (uint128 amount) {
        address user = msg.sender;

        if (!_isPositionExpired(user)) revert Errors.VEPositionNotExpired();
        amount = positionData[user].amount;

        if (amount == 0) revert Errors.VEZeroPosition();

        delete positionData[user];

        pendle.safeTransfer(user, amount);

        emit Withdraw(user, amount);
    }

    /**
     * @notice update & return the current totalSupply
     * @dev state changes expected:
        - _totalSupply & lastSlopeChangeAppliedAt is updated
     */
    function totalSupplyCurrent()
        public
        virtual
        override(IPVeToken, VotingEscrowTokenBase)
        returns (uint128)
    {
        (VeBalance memory supply, ) = _applySlopeChange();
        return supply.getCurrentValue();
    }

    /**
     * @notice broadcast the totalSupply to different chains
     * @dev state changes expected:
        - all chains in chainIds receive the new totalSupply
     */
    function broadcastTotalSupply(uint256[] calldata chainIds) public payable refundUnusedEth {
        _broadcastPosition(address(0), chainIds);
    }

    /**
     * @notice broadcast the position of users to different chains
     * @dev state changes expected:
        - all chains in chainIds receive the new totalSupply & user's new position
     */
    function broadcastUserPosition(address user, uint256[] calldata chainIds)
        public
        payable
        refundUnusedEth
    {
        if (user == address(0)) revert Errors.ZeroAddress();
        _broadcastPosition(user, chainIds);
    }

    function getUserHistoryLength(address user) external view returns (uint256) {
        return userHistory[user].length();
    }

    function getUserHistoryAt(address user, uint256 index)
        external
        view
        returns (Checkpoint memory)
    {
        return userHistory[user].get(index);
    }

    function getBroadcastSupplyFee(uint256[] calldata chainIds)
        external
        view
        returns (uint256[] memory fees)
    {
        fees = new uint256[](chainIds.length);
        for (uint256 i = 0; i < chainIds.length; i++) {
            fees[i] = pendleMsgSendEndpoint.calcFee(
                destinationContracts.get(chainIds[i]),
                chainIds[i],
                SAMPLE_SUPPLY_UPDATE_MESSAGE
            );
        }
    }

    function getBroadcastPositionFee(uint256[] calldata chainIds)
        external
        view
        returns (uint256[] memory fees)
    {
        fees = new uint256[](chainIds.length);
        for (uint256 i = 0; i < chainIds.length; i++) {
            fees[i] = pendleMsgSendEndpoint.calcFee(
                destinationContracts.get(chainIds[i]),
                chainIds[i],
                SAMPLE_POSITION_UPDATE_MESSAGE
            );
        }
    }

    /**
     * @notice increase the locking position of the user
     * @dev it works by simply removing the old position from all relevant data (as if the user has never locked) and
        then add in the new position
      * @dev expected state changes:
        - a new lock with the amount & expiry increase accordingly
        - pendle is taken in if necessary
        - _totalSupply, lastSlopeChangeAppliedAt, slopeChanges, totalSupplyAt is updated
        - a checkpoint is added
     */
    function _increasePosition(
        address user,
        uint128 amountToIncrease,
        uint128 durationToIncrease
    ) internal returns (uint128) {
        LockedPosition memory oldPosition = positionData[user];

        (VeBalance memory newSupply, ) = _applySlopeChange();

        if (!MiniHelpers.isCurrentlyExpired(oldPosition.expiry)) {
            // remove old position not yet expired
            VeBalance memory oldBalance = oldPosition.convertToVeBalance();
            newSupply = newSupply.sub(oldBalance);
            slopeChanges[oldPosition.expiry] -= oldBalance.slope;
        }

        LockedPosition memory newPosition = LockedPosition(
            oldPosition.amount + amountToIncrease,
            oldPosition.expiry + durationToIncrease
        );

        VeBalance memory newBalance = newPosition.convertToVeBalance();
        // add new position
        newSupply = newSupply.add(newBalance);
        slopeChanges[newPosition.expiry] += newBalance.slope;

        _totalSupply = newSupply;
        positionData[user] = newPosition;
        userHistory[user].push(newBalance);
        return newBalance.getCurrentValue();
    }

    /**
     * @notice update the totalSupply, processing all slope changes of past weeks. At the same time, set the finalized
        totalSupplyAt
     * @dev state changes expected:
        - _totalSupply, lastSlopeChangeAppliedAt, totalSupplyAt is updated
     */
    function _applySlopeChange() internal returns (VeBalance memory, uint128) {
        VeBalance memory supply = _totalSupply;
        uint128 wTime = lastSlopeChangeAppliedAt;
        uint128 currentWeekStart = WeekMath.getCurrentWeekStart();

        if (wTime >= currentWeekStart) {
            return (supply, wTime);
        }

        while (wTime < currentWeekStart) {
            wTime += WEEK;
            supply = supply.sub(slopeChanges[wTime], wTime);
            totalSupplyAt[wTime] = supply.getValueAt(wTime);
        }

        _totalSupply = supply;
        lastSlopeChangeAppliedAt = wTime;

        return (supply, wTime);
    }

    /// @notice broadcast position to all chains in chainIds
    function _broadcastPosition(address user, uint256[] calldata chainIds) internal {
        if (chainIds.length == 0) revert Errors.ArrayEmpty();

        (VeBalance memory supply, uint128 wTime) = _applySlopeChange();

        bytes memory userData = (
            user == address(0) ? EMPTY_BYTES : abi.encode(user, positionData[user])
        );

        for (uint256 i = 0; i < chainIds.length; ++i) {
            if (!destinationContracts.contains(chainIds[i]))
                revert Errors.ChainNotSupported(chainIds[i]);
            _broadcast(chainIds[i], wTime, supply, userData);
        }

        if (user != address(0)) {
            emit BroadcastUserPosition(user, chainIds);
        }
        emit BroadcastTotalSupply(supply, chainIds);
    }

    function _afterAddDestinationContract(address, uint256 chainId) internal virtual override {
        (VeBalance memory supply, uint128 wTime) = _applySlopeChange();
        _broadcast(chainId, wTime, supply, EMPTY_BYTES);
    }

    function _broadcast(
        uint256 chainId,
        uint128 wTime,
        VeBalance memory supply,
        bytes memory userData
    ) internal {
        _sendMessage(chainId, abi.encode(wTime, supply, userData));
    }
}
