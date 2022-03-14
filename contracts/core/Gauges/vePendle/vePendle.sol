// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

pragma solidity 0.8.9;
pragma abicoder v2;
import "../../../libraries/Linebrary.sol";
import "./vePendleToken.sol";
import "../../CrosschainContracts/CrosschainSender.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";

// Governance chain vePendle

contract vePendle is vePendleToken, CrosschainSender {
    using LineHelper for Line;
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LOCK_TIME = 1460 days;

    IERC20 public immutable pendle;
    uint256 public lastPendleBalance;
    Destination[] public crosschainVePendles;

    constructor(IERC20 _pendle, uint256 _startTime) EpochController(_startTime) {
        pendle = _pendle;
    }

    function deposit(uint256 expiry) external {
        depositFor(msg.sender, expiry);
    }

    function depositFor(address user, uint256 expiry) public {
        uint256 amount = _consumePendle();
        require(
            expiry % EPOCH_DURATION == 0 && expiry > startTime && expiry > block.timestamp,
            "INVALID_EXPIRY"
        );
        require(balanceOf(user) == 0, "LOCK_EXISTED");
        require(expiry - block.timestamp <= MAX_LOCK_TIME, "LOCK_TIME_TOO_LONG");
        _setUserBalance(user, Line(amount, amount * expiry));
    }

    function increaseLockTime(uint256 duration) external {
        address user = msg.sender;
        require(balanceOf(user) > 0, "LOCK_NOT_EXISTS");
        require(duration % EPOCH_DURATION == 0, "INVALID_DURATION");
        uint256 slope = userLock[user].slope;
        uint256 bias = userLock[user].bias;
        uint256 newExpiry = bias / slope + duration;
        require(newExpiry - block.timestamp <= MAX_LOCK_TIME, "LOCK_TIME_TOO_LONG");
        _setUserBalance(user, Line(slope, slope * newExpiry));
    }

    function increaseLockAmount() external {
        increaseLockAmountFor(msg.sender);
    }

    function increaseLockAmountFor(address user) public {
        uint256 amount = _consumePendle();
        require(balanceOf(user) > 0, "LOCK_NOT_EXISTS");
        uint256 slope = userLock[user].slope;
        uint256 bias = userLock[user].bias;
        uint256 expiry = bias / slope;
        slope += amount;
        _setUserBalance(user, Line(slope, slope * expiry));
    }

    function withdraw() external {
        withdrawFor(msg.sender);
    }

    function withdrawFor(address user) public {
        require(balanceOf(user) == 0, "LOCK_NOT_EXPIRED");
        uint256 amount = userLock[user].slope;
        userLock[user] = Line(0, 0);
        pendle.safeTransfer(user, amount);
    }

    function setCrosschainVePendles(Destination[] calldata newCrosschainVePendles)
        external
        onlyOwner
    {
        delete crosschainVePendles;
        for (uint256 i = 0; i < newCrosschainVePendles.length; ++i) {
            crosschainVePendles.push(newCrosschainVePendles[i]);
        }
    }

    function _consumePendle() internal returns (uint256) {
        uint256 currentBalance = pendle.balanceOf(address(this));
        uint256 consumedAmount = currentBalance - lastPendleBalance;
        lastPendleBalance = currentBalance;
        return consumedAmount;
    }

    function _afterSetBalance(address user) internal override {
        bytes memory data = abi.encode(user, userLock[user].slope, userLock[user].bias);
        _sendDataMultiple(crosschainVePendles, data);
    }
}
