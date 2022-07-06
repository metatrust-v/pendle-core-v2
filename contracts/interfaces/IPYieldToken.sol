// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./IRewardManager.sol";
import "./IPInterestManagerYT.sol";

interface IPYieldToken is IERC20Metadata, IRewardManager, IPInterestManagerYT {
    event Mint(
        address indexed caller,
        address indexed receiverPT,
        address indexed receiverYT,
        uint256 amount
    );
    event Redeem(address indexed caller, address indexed receiver, uint256 amount);

    event RedeemRewards(address indexed user, uint256[] amountRewardsOut);
    event RedeemInterest(address indexed user, uint256 interestOut);

    event WithdrawFeeToTreasury(uint256[] amountRewardsOut, uint256 scyOut);

    function mintPY(address receiverPT, address receiverYT) external returns (uint256 amountPYOut);

    function redeemPY(address receiver) external returns (uint256 amountScyOut);

    function redeemPY(address[] memory receivers, uint256[] memory maxAmountScyOuts)
        external
        returns (uint256 totalAmountScyOut);

    function redeemDueInterestAndRewards(address user)
        external
        returns (uint256 interestOut, uint256[] memory rewardsOut);

    function redeemDueInterest(address user) external returns (uint256 interestOut);

    function redeemDueRewards(address user) external returns (uint256[] memory rewardsOut);

    function rewardIndexesCurrent() external returns (uint256[] memory);

    function scyIndexCurrent() external returns (uint256);

    function scyIndexStored() external view returns (uint256);

    function getRewardTokens() external view returns (address[] memory);

    function SCY() external view returns (address);

    function PT() external view returns (address);

    function factory() external view returns (address);

    function expiry() external view returns (uint256);

    function isExpired() external view returns (bool);
}
