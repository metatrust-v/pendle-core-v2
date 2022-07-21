// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../base-implementations/SCYBaseWithRewards.sol";
import "../../../interfaces/IQiErc20.sol";
import "../../../interfaces/IQiAvax.sol";
import "../../../interfaces/IBenQiComptroller.sol";
import "../../../interfaces/IWETH.sol";
import "../../../interfaces/ISAvax.sol";

import "./PendleQiTokenHelper.sol";

contract PendleQiSAvaxSCY is SCYBaseWithRewards, PendleQiTokenHelper {
    address public immutable QI;
    address public immutable WAVAX;
    address public immutable comptroller;

    address public immutable SAVAX;
    address public immutable QI_SAVAX;

    constructor(
        string memory _name,
        string memory _symbol,
        address _qiSAvax,
        address _WAVAX,
        uint256 _initialExchangeRateMantissa
    )
        SCYBaseWithRewards(_name, _symbol, _qiSAvax)
        PendleQiTokenHelper(_qiSAvax, _initialExchangeRateMantissa)
    {
        require(_qiSAvax != address(0), "zero address");
        require(_WAVAX != address(0), "zero address");

        QI_SAVAX = _qiSAvax;
        WAVAX = _WAVAX;

        SAVAX = _getUnderlyingOfQiSAvax();
        comptroller = IQiToken(_qiSAvax).comptroller();

        QI = IBenQiComptroller(comptroller).qiAddress();

        _safeApprove(SAVAX, QI_SAVAX, type(uint256).max);
    }

    function _getUnderlyingOfQiSAvax() internal view returns (address) {
        try IQiErc20(QI_SAVAX).underlying() returns (address res) {
            return res;
        } catch {
            return NATIVE;
        }
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SCYBase-_deposit}
     *
     * The underlying yield token is qiToken (qiSAvax). If the base token deposited is underlying asset, the function
     * first convert those deposited SAvax into qiSAvax. Then the corresponding amount of shares is returned.
     *
     * The exchange rate of qiToken (qiSAvax) to shares is 1:1
     */
    function _deposit(address tokenIn, uint256 amount)
        internal
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == QI_SAVAX) {
            amountSharesOut = amount;
        } else {
            // tokenIn is underlying sAvax -> convert it into qiSAvax first
            uint256 preBalanceQiSAvax = _selfBalance(QI_SAVAX);

            uint256 errCode = IQiErc20(QI_SAVAX).mint(amount);
            require(errCode == 0, "mint failed");

            amountSharesOut = _selfBalance(QI_SAVAX) - preBalanceQiSAvax;
        }
    }

    /**
     * @dev See {SCYBase-_redeem}
     *
     * The shares are redeemed into the same amount of qiTokens (qiSAvax). If `tokenOut` is the underlying asset sAvax,
     * the function also redeems said asset from the corresponding amount of qiToken (qiSAvax).
     */
    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == QI_SAVAX) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            uint256 preBalanceUnderlying = _selfBalance(SAVAX);

            uint256 errCode = IQiErc20(QI_SAVAX).redeem(amountSharesToRedeem);
            require(errCode == 0, "redeem failed");

            // Even though underlying is not rewardToken, we still manually check balance for accounting purposes.
            amountTokenOut = _selfBalance(SAVAX) - preBalanceUnderlying;
        }
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates and updates the exchange rate of shares to underlying asset token
     * @dev It is the exchange rate of qiSAvax to native Avax token, this is calculated from sAvax to QiSAvax Exchange rate and then followed by converting that exchange rate relative to native Avax exchange rate.
     */
    function exchangeRate() public view override returns (uint256) {
        uint256 sAvaxToQiSAvaxExchangeRate = _exchangeRateCurrentView();
        return ISAvax(SAVAX).getPooledAvaxByShares(sAvaxToQiSAvaxExchangeRate);
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-getRewardTokens}
     */
    function _getRewardTokens() internal view override returns (address[] memory res) {
        res = new address[](2);
        res[0] = QI;
        res[1] = WAVAX;
    }

    function _redeemExternalReward() internal override {
        address[] memory holders = new address[](1);
        address[] memory qiTokens = new address[](1);
        holders[0] = address(this);
        qiTokens[0] = QI_SAVAX;

        IBenQiComptroller(comptroller).claimReward(0, holders, qiTokens, false, true);
        IBenQiComptroller(comptroller).claimReward(1, holders, qiTokens, false, true);

        if (address(this).balance != 0) IWETH(WAVAX).deposit{ value: address(this).balance };
    }

    /*///////////////////////////////////////////////////////////////
                    MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-getBaseTokens}
     */
    function getBaseTokens() public view override returns (address[] memory res) {
        res = new address[](2);
        res[0] = QI_SAVAX;
        res[1] = SAVAX;
    }

    /**
     * @dev See {ISuperComposableYield-isValidBaseToken}
     */
    function isValidBaseToken(address token) public view override returns (bool res) {
        res = (token == SAVAX || token == QI_SAVAX);
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
        return (AssetType.TOKEN, SAVAX, IERC20Metadata(SAVAX).decimals());
    }
}
