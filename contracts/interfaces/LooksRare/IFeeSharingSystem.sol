// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

interface IFeeSharingSystem {
    function looksRareToken() external view returns (address);

    function rewardToken() external view returns (address);

    function tokenDistributor() external view returns (address);

    function currentRewardPerBlock() external view returns (uint256);

    function totalShares() external view returns (uint256);

    /**
     * @notice Deposit staked tokens (and collect reward tokens if requested)
     * @param amount amount to deposit (in LOOKS)
     * @param claimRewardToken whether to claim reward tokens
     * @dev There is a limit of 1 LOOKS per deposit to prevent potential manipulation of current shares
     */
    function deposit(uint256 amount, bool claimRewardToken) external;

    /**
     * @notice Harvest reward tokens that are pending
     */
    function harvest() external;

    /**
     * @notice Withdraw staked tokens (and collect reward tokens if requested)
     * @param shares shares to withdraw
     * @param claimRewardToken whether to claim reward tokens
     */
    function withdraw(uint256 shares, bool claimRewardToken) external;

    /**
     * @notice Calculate value of LOOKS for a user given a number of shares owned
     * @param user address of the user
     */
    function calculateSharesValueInLOOKS(address user) external view returns (uint256);

    /**
     * @notice Calculate price of one share (in LOOKS token)
     * Share price is expressed times 1e18
     */
    function calculateSharePriceInLOOKS() external view returns (uint256);

    /**
     * @notice Return last block where trading rewards were distributed
     */
    function lastRewardBlock() external view returns (uint256);
}
