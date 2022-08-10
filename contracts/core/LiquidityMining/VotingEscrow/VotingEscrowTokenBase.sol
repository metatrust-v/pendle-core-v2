// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../../interfaces/IPVeToken.sol";
import "../../../libraries/VeBalanceLib.sol";
import "../../../libraries/math/WeekMath.sol";
import "../../../libraries/helpers/MiniHelpers.sol";

/**
 * @dev this contract is an abstract for its mainchain and sidechain variant
 * PRINCIPLE:
 *   - All functions implemented in this contract should be either view or pure
 *     to ensure that no writing logic is inheritted by sidechain version
 *   - Mainchain version will handle the logic which are:
 *        + Deposit, withdraw, increase lock, increase amount
 *        + Mainchain logic will be ensured to have _totalSupply = linear sum of
 *          all users' veBalance such that their locks are not yet expired
 *        + Mainchain contract reserves 100% the right to write on sidechain
 *        + No other transaction is allowed to write on sidechain storage
 */

abstract contract VotingEscrowTokenBase is IPVeToken {
    using VeBalanceLib for VeBalance;
    using VeBalanceLib for LockedPosition;

    uint128 public constant WEEK = 1 weeks;
    uint128 public constant MAX_LOCK_TIME = 104 weeks;

    VeBalance internal _totalSupply;
    uint128 public lastSlopeChangeAppliedAt;

    mapping(address => LockedPosition) public positionData;

    constructor() {
        lastSlopeChangeAppliedAt = WeekMath.getCurrentWeekStart();
    }

    function balanceOf(address user) public view virtual returns (uint128) {
        return positionData[user].convertToVeBalance().getCurrentValue();
    }

    function totalSupplyStored() public view virtual returns (uint128) {
        return _totalSupply.getCurrentValue();
    }

    function totalSupplyCurrent() public virtual returns (uint128);

    function _isPositionExpired(address user) internal view returns (bool) {
        return MiniHelpers.isCurrentlyExpired(positionData[user].expiry);
    }

    function totalSupplyAndBlanaceCurrent(address user) external returns (uint128, uint128) {
        return (balanceOf(user), totalSupplyCurrent());
    }
}
