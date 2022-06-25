// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "../../libraries/RewardManagerAbstract.sol";
import "../../libraries/math/Math.sol";
import "../../libraries/helpers/ArrayLib.sol";

abstract contract RewardManagerYT is RewardManagerAbstract {
    using Math for uint256;
    using ArrayLib for uint256[];

    // [token] => [user] => (index,accured)
    mapping(address => mapping(address => UserReward)) public userReward;

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

    function _doTransferOutRewards(address user, address receiver)
        internal
        virtual
        returns (uint256[] memory rewardAmounts)
    {
        _redeemExternalReward();

        address[] memory tokens = _getRewardTokens();
        rewardAmounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            rewardAmounts[i] = userReward[tokens[i]][user].accrued;
            if (rewardAmounts[i] != 0) {
                userReward[tokens[i]][user].accrued = 0;
                _transferOut(tokens[i], receiver, rewardAmounts[i]);
            }
        }
    }
}
