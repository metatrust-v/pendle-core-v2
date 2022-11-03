// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../SYBase.sol";
import "../../../interfaces/ILooksFeeSharing.sol";
import "../../../interfaces/ILooksStaking.sol";

/**
 * @dev
 * Firstly, LOOKS holder has an option to stake their token into Looksrare's TokenDistributor to earn LOOKS over time
 * Ref: https://github.com/LooksRare/contracts-token-staking/blob/master/contracts/TokenDistributor.sol
 * 
 * Secondly, instead of staking to TokenDistributor, users can stake their token to a contract called FeeSharingSystem to auto-compound their earned LOOKS to TokenDistributor
 * This contract also implements a FeeSharing mechanism (collected from protocol) in WETH 
 * Ref: https://github.com/LooksRare/contracts-token-staking/blob/master/contracts/FeeSharingSystem.sol
 * 
 * On top of this, they've built a contract to auto-compound earned ETH to LOOKS by selling ETH on Uniswap V3 and stake them to FeeSharingSystem
 * Ref: https://github.com/LooksRare/contracts-token-staking/blob/master/contracts/AggregatorFeeSharingWithUniswapV3.sol
 * 
 * ETH fee will be continuously claimed, and only sold on UniV3 once it reached a certain amount, and not lower than some price (for gas saving purpose only).
 */

contract PendleLooksStakingSY is SYBase {
    using Math for uint256;

    address public immutable looks;
    address public immutable stakingContract;
    address public immutable feeSharingContract;

    constructor(
        string memory _name,
        string memory _symbol,
        address _looks,
        address _stakingContract,
        address _feeSharingContract
    ) SYBase(_name, _symbol, _looks) {
        looks = _looks;
        stakingContract = _stakingContract;
        feeSharingContract = _feeSharingContract;

        _safeApproveInf(_looks, _stakingContract);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address, uint256 amountDeposited)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        uint256 previousShare = ILooksStaking(stakingContract).userInfo(address(this));
        ILooksStaking(stakingContract).deposit(amountDeposited);
        amountSharesOut = ILooksStaking(stakingContract).userInfo(address(this)) - previousShare;
    }

    function _redeem(
        address receiver,
        address,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        uint256 previousBalance = _selfBalance(looks);
        ILooksStaking(stakingContract).withdraw(amountSharesToRedeem);
        amountTokenOut = _selfBalance(looks) - previousBalance;
        _transferOut(looks, receiver, amountTokenOut);
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        uint256 totalShares = ILooksStaking(stakingContract).totalShares();
        uint256 totalLooks = ILooksFeeSharing(feeSharingContract).calculateSharesValueInLOOKS(
            stakingContract
        );
        return totalLooks.divDown(totalShares);
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev LooksRare also uses 1e18 precision, so it is accurate to
     * calculate preview results using our built-in exchangeRate function
     */
    function _previewDeposit(address, uint256 amountTokenToDeposit)
        internal
        view
        override
        returns (uint256 amountSharesOut)
    {
        amountSharesOut = amountTokenToDeposit.divDown(exchangeRate());
    }

    function _previewRedeem(address, uint256 amountSharesToRedeem)
        internal
        view
        override
        returns (uint256 amountTokenOut)
    {
        amountTokenOut = amountSharesToRedeem.mulDown(exchangeRate());
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = looks;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = looks;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == looks;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == looks;
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
        return (AssetType.TOKEN, looks, IERC20Metadata(looks).decimals());
    }
}
