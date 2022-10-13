// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../SYBase.sol";
import "../../../interfaces/ITruefiPool2.sol";

contract PendleTruefiPoolSY is SYBase {
    using Math for uint256;

    address public immutable tfToken;
    address public immutable underlying;

    uint256 private constant TF_BASIS_PRECISION = 10000;

    constructor(
        string memory _name,
        string memory _symbol,
        address _tfToken
    ) SYBase(_name, _symbol, _tfToken) {
        tfToken = _tfToken;
        underlying = ITruefiPool2(tfToken).token();
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address tokenIn, uint256 amountDeposited)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == tfToken) {
            amountSharesOut = amountDeposited;
        } else {
            uint256 preTfBalanace = _selfBalance(tfToken);
            ITruefiPool2(tfToken).join(amountDeposited);
            amountSharesOut = _selfBalance(tfToken) - preTfBalanace;
        }
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        if (tokenOut == tfToken) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            uint256 preUnderlyingBalance = _selfBalance(underlying);
            // TrueFi already reverts if there's not enough balance to redeem
            ITruefiPool2(tfToken).liquidExit(amountSharesToRedeem);
            amountTokenOut = _selfBalance(underlying) - preUnderlyingBalance;
        }
        _transferOut(tokenOut, receiver, amountTokenOut);
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return ITruefiPool2(tfToken).poolValue().divDown(ITruefiPool2(tfToken).totalSupply());
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == tfToken) amountSharesOut = amountTokenToDeposit;
        else {
            uint256 joiningFee = ITruefiPool2(tfToken).joiningFee();
            uint256 netAmountTokenToDeposit = (amountTokenToDeposit *
                (TF_BASIS_PRECISION - joiningFee)) / TF_BASIS_PRECISION;
            amountSharesOut = netAmountTokenToDeposit.divDown(exchangeRate());
        }
    }

    function _previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        view
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == tfToken) amountTokenOut = amountSharesToRedeem;
        else {
            uint256 exitingAmount = amountSharesToRedeem.mulDown(exchangeRate());
            uint256 netProportionOut = ITruefiPool2(tfToken).liquidExitPenalty(exitingAmount);
            amountTokenOut = exitingAmount * netProportionOut / TF_BASIS_PRECISION;
        }
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = underlying;
        res[1] = tfToken;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = underlying;
        res[1] = tfToken;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == underlying || token == tfToken;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == underlying || token == tfToken;
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
        return (AssetType.TOKEN, underlying, IERC20Metadata(underlying).decimals());
    }
}
