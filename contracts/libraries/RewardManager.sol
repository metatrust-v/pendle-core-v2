// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "../interfaces/IRewardManager.sol";
import "./RewardManagerAbstract.sol";
import "./math/Math.sol";
import "../libraries/helpers/ArrayLib.sol";

/// This RewardManager can be used with any contracts, regardless of what tokens that contract stores
/// since the RewardManager will maintain its own internal balance
abstract contract RewardManager is RewardManagerAbstract {
    using Math for uint256;
    using ArrayLib for uint256[];

    uint256 public lastRewardBlock;

    mapping(address => RewardState) public rewardState;

    // [token] => [user] => (index,accured)
    mapping(address => mapping(address => UserReward)) public userReward;

    function _updateAndDistributeRewards(address user) internal virtual {
        _updateAndDistributeRewardsForTwo(user, address(0));
    }

    function _updateAndDistributeRewardsForTwo(address user1, address user2) internal virtual {
        _updateRewardIndex();
        _distributeRewardsForTwo(user1, user2);
    }

    function _updateRewardIndex() internal virtual {
        if (lastRewardBlock == block.number) return;
        lastRewardBlock = block.number;

        uint256 totalShares = _rewardSharesTotal();
        address[] memory tokens = _getRewardTokens();
        uint256[] memory preBalances = _selfBalances(tokens);

        _redeemExternalReward();

        uint256[] memory accrued = _selfBalances(tokens).sub(preBalances);

        for (uint256 i = 0; i < tokens.length; ++i) {
            address token = tokens[i];
            uint256 index = rewardState[token].index;

            if (index == 0) index = INITIAL_REWARD_INDEX;
            if (totalShares != 0) index += accrued[i].divDown(totalShares);

            rewardState[token].index = index.Uint128();
            rewardState[token].lastBalance += accrued[i].Uint128();
        }
    }

    function _distributeRewards(
        address user,
        address[] memory tokens,
        uint256[] memory indexes
    ) internal override {
        uint256 userShares = _rewardSharesUser(user);

        for (uint256 i = 0; i < tokens.length; ++i) {
            address token = tokens[i];
            uint256 index = indexes[i];
            uint256 userIndex = userReward[token][user].index;

            if (userIndex == 0) userIndex = index;
            if (userIndex == index) continue;

            uint256 deltaIndex = index - userIndex;
            uint256 rewardDelta = userShares.mulDown(deltaIndex);
            uint256 rewardAccrued = userReward[token][user].accrued + rewardDelta;

            userReward[token][user] = UserReward({
                index: index.Uint128(),
                accrued: rewardAccrued.Uint128()
            });
        }
    }

    /// @dev this function doesn't need redeemExternal since redeemExternal is bundled in updateRewardIndex
    /// @dev this function also has to update rewardState.lastBalance
    function _doTransferOutRewards(address user, address receiver)
        internal
        virtual
        returns (uint256[] memory rewardAmounts)
    {
        address[] memory tokens = _getRewardTokens();
        rewardAmounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            rewardAmounts[i] = userReward[tokens[i]][user].accrued;
            if (rewardAmounts[i] != 0) {
                userReward[tokens[i]][user].accrued = 0;
                rewardState[tokens[i]].lastBalance -= rewardAmounts[i].Uint128();
                _transferOut(tokens[i], receiver, rewardAmounts[i]);
            }
        }
    }

    function _getRewardTokensAndIndexes()
        internal
        view
        override
        returns (address[] memory tokens, uint256[] memory indexes)
    {
        tokens = _getRewardTokens();
        indexes = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) indexes[i] = rewardState[tokens[i]].index;
    }
}
