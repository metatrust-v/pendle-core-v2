// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../interfaces/ISuperComposableYield.sol";
import "./SCYBaseWithRewards.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../libraries/math/Math.sol";

/// This contract makes an important assumption that yieldToken is never a rewardToken
/// Please make sure that assumption always holds
abstract contract SCYBaseWithDynamicRewards is SCYBaseWithRewards {
    address[] public currentExtraRewards;

    constructor(
        string memory _name,
        string memory _symbol,
        address _yieldToken,
        address[] memory _currentExtraRewards
    )
        SCYBaseWithRewards(_name, _symbol, _yieldToken) // solhint-disable-next-line no-empty-blocks
    {
        for (uint256 i = 0; i < _currentExtraRewards.length; i++) {
            currentExtraRewards[i] = _currentExtraRewards[i];
        }
    }
}
