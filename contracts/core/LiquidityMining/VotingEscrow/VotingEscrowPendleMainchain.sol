// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "../../../interfaces/IPVotingEscrow.sol";
import "./VotingEscrowToken.sol";
import "../CelerAbstracts/CelerSender.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract VotingEscrowPendleMainchain is VotingEscrowToken, IPVotingEscrow, CelerSender {
    using SafeERC20 for IERC20;
    using VeBalanceLib for VeBalance;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    bytes private constant EMPTY_BYTES = abi.encode();

    IERC20 public immutable pendle;

    mapping(uint128 => uint128) private slopeChanges;

    // Saving totalSupply checkpoint for each week, later can be used for reward accounting
    mapping(uint128 => uint128) public totalSupplyAt;

    // Saving VeBalance checkpoint for users of each week, can later use binary search
    // to ask for their vePendle balance at any timestamp
    mapping(address => Checkpoint[]) public userCheckpoints;

    constructor(IERC20 _pendle, address _governanceManager) CelerSender(_governanceManager) {
        pendle = _pendle;
    }

    // the expiry % WEEK is just very bug prone and easy to forget
    // input's validation should go first, then come internal data validation
    function lock(uint128 amount, uint128 expiry) external returns (uint128) {
        address user = msg.sender;
        require(
            expiry == WeekMath.getWeekStartTimestamp(expiry) && expiry > block.timestamp,
            "invalid expiry"
        );
        require(expiry <= block.timestamp + MAX_LOCK_TIME, "max lock time exceeded");
        require(positionData[user].amount == 0, "lock not withdrawed"); // inappropriate comments
        require(amount > 0, "zero amount");

        pendle.safeTransferFrom(user, address(this), amount);
        // it's good to note what this function is returning here
        return _increasePosition(user, expiry, amount);
    }

    /**
     * @dev strict condition, user can only increase lock duration for themselves
     */
    function increaseLockDuration(uint128 duration) external returns (uint128) {
        address user = msg.sender;
        require(!isPositionExpired(user), "user position expired");
        require(duration > 0 && WeekMath.isValidDuration(duration), "invalid duration"); // duration % WEEK check looks meh
        require(
            positionData[user].expiry + duration <= block.timestamp + MAX_LOCK_TIME,
            "max lock time exceeded"
        );

        return _increasePosition(user, duration, 0);
    }

    /**
     * @dev anyone can top up one user's pendle locked amount
     */
    function increaseLockAmount(uint128 amount) external returns (uint128 newVeBalance) {
        address user = msg.sender;
        require(!isPositionExpired(user), "user position expired");

        require(amount > 0, "zero amount");
        pendle.safeTransferFrom(user, address(this), amount);
        return _increasePosition(user, 0, amount);
    }

    /**
     * @dev there is not a need for broadcasting in withdrawing thanks to the definition of _totalSupply
     */
    // huh why suddenly allows the withdraw of a random user?
    // Also, there should be a function to allow users to renew the lock position?
    function withdraw(address user) external returns (uint128 amount) {
        require(isPositionExpired(user), "user position not expired");
        amount = positionData[user].amount; // should require amount != 0
        require(amount > 0, "position already withdrawed");
        positionData[user] = LockedPosition(0, 0);
        pendle.safeTransfer(user, amount);
    }

    function totalSupplyCurrent() external virtual override returns (uint128) {
        (VeBalance memory supply, ) = _updateGlobalSupply();
        return supply.getCurrentValue();
    }

    // do we really need to like broadcast all the chains at once?
    function broadcastTotalSupply() public payable {
        (VeBalance memory supply, uint128 timestamp) = _updateGlobalSupply();
        uint256 length = sidechainContracts.length();

        for (uint256 i = 0; i < length; ++i) {
            (uint256 chainId, ) = sidechainContracts.at(i);
            _broadcast(chainId, timestamp, supply, EMPTY_BYTES);
        }
    }

    // for users, hmm suddenly we need to pass in the list of chains to broadcast, not very fun
    function broadcastUserPosition(address user, uint256[] calldata chainIds) external payable {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            uint256 chainId = chainIds[i];
            require(sidechainContracts.contains(chainId), "not supported chain");
            _broadcast(chainId, timestamp, supply, abi.encode(user, positionData[user]));
        }
    }

    /**
     * @dev in case of creating a new position, position should already be set to (0, 0), and expiryToIncrease = expiry
     * @dev in other cases, expiryToIncrease = additional-duration and amountToIncrease = additional-pendle
     */
    function _increasePosition(
        address user,
        uint128 expiryToIncrease, // duration to increase btw
        uint128 amountToIncrease
    ) internal returns (uint128) {
        LockedPosition memory oldPosition = positionData[user];

        (VeBalance memory supply, ) = _updateGlobalSupply();
        if (oldPosition.expiry > block.timestamp) {
            // remove old position not yet expired
            VeBalance memory oldBalance = convertToVeBalance(oldPosition);
            supply = supply.sub(oldBalance);
            slopeChanges[oldPosition.expiry] -= oldBalance.slope;
        }

        LockedPosition memory newPosition = LockedPosition(
            oldPosition.amount + amountToIncrease,
            oldPosition.expiry + expiryToIncrease
        );

        VeBalance memory newBalance = convertToVeBalance(newPosition);
        {
            // add new position
            slopeChanges[newPosition.expiry] += newBalance.slope; // the order should be similar to other parts
            supply = supply.add(newBalance);
        }

        _totalSupply = supply;
        positionData[user] = newPosition;
        userCheckpoints[user].push(Checkpoint(newBalance, uint128(block.timestamp)));
        return newBalance.getCurrentValue();
    }

    function _updateGlobalSupply() internal returns (VeBalance memory, uint128) {
        // this looks damn confusing, supply & timestamp is reused
        VeBalance memory supply = _totalSupply;
        uint128 timestamp = lastSupplyUpdatedAt;
        uint128 currentWeekStart = WeekMath.getCurrentWeekStartTimestamp();

        if (timestamp >= currentWeekStart) {
            return (supply, timestamp);
        }

        while (timestamp < currentWeekStart) {
            timestamp += WEEK;
            supply = supply.sub(slopeChanges[timestamp], timestamp);
            totalSupplyAt[timestamp] = supply.getValueAt(timestamp);
        }

        _totalSupply = supply;
        lastSupplyUpdatedAt = timestamp;

        return (supply, lastSupplyUpdatedAt);
    }

    function _afterAddSidechainContract(address, uint256 chainId) internal virtual override {
        (VeBalance memory supply, uint256 timestamp) = _updateGlobalSupply();
        _broadcast(chainId, timestamp, supply, EMPTY_BYTES);
    }

    function _broadcast(
        uint256 chainId,
        uint256 timestamp,
        VeBalance memory supply,
        bytes memory userData
    ) internal {
        _sendMessage(chainId, abi.encode(timestamp, supply, userData));
    }
}
