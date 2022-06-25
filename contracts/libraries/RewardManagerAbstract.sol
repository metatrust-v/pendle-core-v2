// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "../interfaces/IRewardManager.sol";
import "./helpers/TokenHelper.sol";

abstract contract RewardManagerAbstract is IRewardManager, TokenHelper {
    struct RewardState {
        uint128 index;
        uint128 lastBalance;
    }

    struct UserReward {
        uint128 index;
        uint128 accrued;
    }

    uint256 internal constant INITIAL_REWARD_INDEX = 1;

    function _distributeRewards(address user) internal virtual {
        _distributeRewardsForTwo(user, address(0));
    }

    function _distributeRewardsForTwo(address user1, address user2) internal virtual {
        // no updateRewardIndex since we rely on SCY's rewardIndexes
        (address[] memory tokens, uint256[] memory indexes) = _getRewardTokensAndIndexes();
        if (user1 != address(0) && user1 != address(this))
            _distributeRewards(user1, tokens, indexes);
        if (user2 != address(0) && user2 != address(this))
            _distributeRewards(user2, tokens, indexes);
    }

    function _distributeRewards(
        address user,
        address[] memory tokens,
        uint256[] memory indexes
    ) internal virtual;

    function _redeemExternalReward() internal virtual;

    function _getRewardTokensAndIndexes()
        internal
        virtual
        returns (address[] memory, uint256[] memory);

    function _getRewardTokens() internal view virtual returns (address[] memory);

    function _rewardSharesUser(address user) internal view virtual returns (uint256);

    function _rewardSharesTotal() internal view virtual returns (uint256);
}
