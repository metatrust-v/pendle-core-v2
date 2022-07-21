// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../base-implementations/SCYBaseWithRewards.sol";
import "../../../interfaces/LooksRare/ILooksRareToken.sol";
import "../../../interfaces/LooksRare/IFeeSharingSystem.sol";
import "../../../interfaces/IWETH.sol";

/*
LooksRare Staking of LOOKS to earn reward token - WETH (2% of Trading Fees on all sales of NFTs from the NFT Marketplace excluding private sales since no fee taken)

All the WETH collected from these fees are consolidated at the end of each recurring 6,500 Ethereum block period (roughly 24 hours) and then distributed to LOOKS stakers in a linear format per block over the next 6,500 block period.


*Reward Claiming -> Any time any day

*2 Types of Staking: [Active, Passive]

The main difference between Active and Passive stakers is that LOOKS in passive staking do NOT earn additional LOOKS while staked.

1. Passive Staking - Stakers whose LOOKS tokens are locked for trading but unlocked for staking: namely Team, Treasury and Strategic sale tokens (https://docs.looksrare.org/about/looks-tokenomics)

*At the start of each 6,500 block period, a portion of the WETH fees collected from the previous 6,500 blocks are sent to the Passive Staking address. 

**Amount of WETH Fees from previous 6,500 blocks = (Total amount of LOOKS staked passively at start of period / Total amount of LOOKS staked at start of period (passive + active))

***Each user’s amount of staked LOOKS at each block is then compared against the total amount of LOOKS staked at each block, with this being done at every block within the 6,500 block period to find the total amount of WETH rewards received.

2. Active Staking - Majority of stakers, whose staked LOOKS tokens are fully unlocked.


Yield Generating Mechanism - Stake LOOKS in Looksrare 

Asset - LOOKS

Shares - WETH

Exchange Rate - Increases with LOOKS Rewards


*Note:

FeeSharingSystem -> Staking Contract to support deposit, withdrawal, harvesting of rewards & calculation of rewards (for exchange rates -> calculateSharesValueInLOOKS)

LooksrareToken -> ERC-20 Contract

*/

abstract contract PendleLooksRareSCY is SCYBaseWithRewards {
    address public immutable LOOKSRARE;
    address public immutable FEE_SHARING_SYSTEM;
    address public immutable WETH;

    constructor(
        string memory _name,
        string memory _symbol,
        address _feeSharingSystem
    )
        SCYBaseWithRewards(_name, _symbol, _feeSharingSystem) // since its shares from LOOKS
    {
        require(_feeSharingSystem != address(0), "zero address");

        FEE_SHARING_SYSTEM = _feeSharingSystem;

        (LOOKSRARE, WETH) = _getUnderlyingAndRewardToken();

        _safeApprove(LOOKSRARE, FEE_SHARING_SYSTEM, type(uint256).max);
    }

    function _getUnderlyingAndRewardToken()
        internal
        view
        returns (address looksrare, address weth)
    {
        IFeeSharingSystem FeeSharingSystem = IFeeSharingSystem(FEE_SHARING_SYSTEM);

        looksrare = FeeSharingSystem.looksRareToken();
        weth = FeeSharingSystem.rewardToken();
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SCYBase-_deposit}
     *
     * The underlying yield token is shares of LooksRare staking. Deposit should only accept LOOKS token and will based on the corresponding amount of shares topped up, shares to SCY will be 1:1.
     */
    function _deposit(address, uint256 amount)
        internal
        override
        returns (uint256 amountSharesOut)
    {
        IFeeSharingSystem FeeSharingSystem = IFeeSharingSystem(FEE_SHARING_SYSTEM);

        uint256 preBalanceShares = FeeSharingSystem.totalShares();

        FeeSharingSystem.deposit(amount, false); // No reward claim

        amountSharesOut = FeeSharingSystem.totalShares() - preBalanceShares;
    }

    /**
     * @dev See {SCYBase-_redeem}
     *
     * The shares are redeemed into the corresponding amount of LOOKS token based on the prevailing exchange rate.
     *
     * This function withdraws staked tokens (without collecting reward tokens)
     */
    function _redeem(address, uint256 amountSharesToRedeem)
        internal
        override
        returns (uint256 amountTokenOut)
    {
        IFeeSharingSystem(FEE_SHARING_SYSTEM).withdraw(amountSharesToRedeem, false);

        amountTokenOut = (amountSharesToRedeem * exchangeRate()) / 1e18;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculate price of one share (in LOOKS token)
     * Share price is expressed times 1e18
     * @dev estimated number of LOOKS for a user given the number of owned shares
     */
    function exchangeRate() public view override returns (uint256) {
        return IFeeSharingSystem(FEE_SHARING_SYSTEM).calculateSharePriceInLOOKS();
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-getRewardTokens}
     *Get Extra Rewards from SCYBaseWithRewards Contract immutable variables. To update, simply use a proxy and update with the new rewards.
     **/
    function _getRewardTokens() internal view override returns (address[] memory res) {
        res = new address[](1);
        res[0] = WETH;
    }

    /**
     * @dev Receive all WETH Extra rewards from standard staking.
     */
    function _redeemExternalReward() internal override {
        IFeeSharingSystem(FEE_SHARING_SYSTEM).harvest();
    }

    /*///////////////////////////////////////////////////////////////
                    MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Only receives LOOKS for deposit, and previews amount of shares based on prevailing exchange rate
     */
    function _previewDeposit(address, uint256 amountTokenToDeposit)
        internal
        view
        override
        returns (uint256 amountSharesOut)
    {
        amountSharesOut = (amountTokenToDeposit * 1e18) / exchangeRate();
    }

    function _previewRedeem(address, uint256 amountSharesToRedeem)
        internal
        view
        override
        returns (uint256 amountTokenOut)
    {
        amountTokenOut = (amountSharesToRedeem * exchangeRate()) / 1e18;
    }

    /**
     * @dev See {ISuperComposableYield-getBaseTokens}
     */
    function getBaseTokens() public view override returns (address[] memory res) {
        res = new address[](1);
        res[0] = LOOKSRARE;
    }

    /**
     * @dev See {ISuperComposableYield-isValidBaseToken}
     */
    function isValidBaseToken(address token) public view override returns (bool res) {
        res = (token == LOOKSRARE);
    }

    function assetInfo()
        external
        view
        returns (
            AssetType assetType,
            address assetAddress,
            uint8 assetDecimals
        )
    {
        return (AssetType.TOKEN, LOOKSRARE, IERC20Metadata(LOOKSRARE).decimals());
    }
}
