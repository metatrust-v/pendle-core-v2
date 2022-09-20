// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPMarketSwapCallback.sol";
import "../../libraries/SCY/SCYUtilsUC.sol";
import "../../libraries/math/MarketApproxLibUC.sol";
import "./base/ActionBaseMintRedeem.sol";
import "./base/CallbackHelper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ActionCallback is IPMarketSwapCallback, CallbackHelper {
    using MathUC for int256;
    using MathUC for uint256;
    using SafeERC20 for ISuperComposableYield;
    using SafeERC20 for IPYieldToken;
    using SafeERC20 for IPPrincipalToken;
    using SafeERC20 for IERC20;
    using PYIndexLibUC for PYIndex;
    using PYIndexLibUC for IPYieldToken;

    address public immutable marketFactory;

    modifier onlyPendleMarket(address market) {
        require(IPMarketFactory(marketFactory).isValidMarket(market), "INVALID_MARKET");
        _;
    }

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _marketFactory) {
        require(_marketFactory != address(0), "zero address");
        marketFactory = _marketFactory;
    }

    /**
     * @dev The callback is only callable by a Pendle Market created by the factory
     */
    function swapCallback(
        int256 ptToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) external override onlyPendleMarket(msg.sender) {
        unchecked {
            address market = msg.sender;
            ActionType swapType = _getActionType(data);
            if (swapType == ActionType.SwapExactScyForYt) {
                _callbackSwapExactScyForYt(market, ptToAccount, scyToAccount, data);
            } else if (swapType == ActionType.SwapScyForExactYt) {
                _callbackSwapScyForExactYt(market, ptToAccount, scyToAccount, data);
            } else if (swapType == ActionType.SwapYtForScy) {
                _callbackSwapYtForScy(market, ptToAccount, scyToAccount, data);
            } else if (swapType == ActionType.SwapExactYtForPt) {
                _callbackSwapExactYtForPt(market, ptToAccount, scyToAccount, data);
            } else if (swapType == ActionType.SwapExactPtForYt) {
                _callbackSwapExactPtForYt(market, ptToAccount, scyToAccount, data);
            } else {
                require(false, "unknown swapType");
            }
        }
    }

    /// @dev refer to _swapExactScyForYt
    function _callbackSwapExactScyForYt(
        address market,
        int256 ptToAccount,
        int256, /*scyToAccount*/
        bytes calldata data
    ) internal {
        unchecked {
            (, , IPYieldToken YT) = IPMarket(market).readTokens();
            (address receiver, uint256 minYtOut) = _decodeSwapExactScyForYt(data);

            uint256 ptOwed = ptToAccount.abs();
            uint256 netPyOut = YT.mintPY(market, receiver);

            require(netPyOut >= ptOwed, "insufficient PT to pay");
            require(netPyOut >= minYtOut, "insufficient YT out");
        }
    }

    struct VarsSwapScyForExactYt {
        address payer;
        address receiver;
        uint256 maxScyToPull;
    }

    /// @dev refer to _swapScyForExactYt
    function _callbackSwapScyForExactYt(
        address market,
        int256 ptToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        unchecked {
            VarsSwapScyForExactYt memory vars;
            (vars.payer, vars.receiver, vars.maxScyToPull) = _decodeSwapScyForExactYt(data);
            (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

            /// ------------------------------------------------------------
            /// calc totalScyNeed
            /// ------------------------------------------------------------
            PYIndex pyIndex = YT.newIndex();
            uint256 ptOwed = ptToAccount.abs();
            uint256 totalScyNeed = pyIndex.assetToScyUp(ptOwed);

            /// ------------------------------------------------------------
            /// calc netScyToPull
            /// ------------------------------------------------------------
            uint256 scyReceived = scyToAccount.Uint();
            uint256 netScyToPull = totalScyNeed.subMax0(scyReceived);
            require(netScyToPull <= vars.maxScyToPull, "exceed SCY in limit");

            /// ------------------------------------------------------------
            /// mint & transfer
            /// ------------------------------------------------------------
            if (netScyToPull > 0) {
                SCY.safeTransferFrom(vars.payer, address(YT), netScyToPull);
            }

            uint256 netPyOut = YT.mintPY(market, vars.receiver);
            require(netPyOut >= ptOwed, "insufficient pt to pay");
        }
    }

    /// @dev refer to _swapExactYtForScy or _swapYtForExactScy
    function _callbackSwapYtForScy(
        address market,
        int256 ptToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        unchecked {
            (address receiver, uint256 minScyOut) = _decodeSwapYtForScy(data);
            (, , IPYieldToken YT) = IPMarket(market).readTokens();
            PYIndex pyIndex = YT.newIndex();

            uint256 scyOwed = scyToAccount.neg().Uint();

            address[] memory receivers = new address[](2);
            uint256[] memory amountPYToRedeems = new uint256[](2);

            (receivers[0], amountPYToRedeems[0]) = (market, pyIndex.scyToAsset(scyOwed));
            (receivers[1], amountPYToRedeems[1]) = (
                receiver,
                ptToAccount.Uint() - amountPYToRedeems[0]
            );

            uint256[] memory amountScyOuts = YT.redeemPYMulti(receivers, amountPYToRedeems);
            require(amountScyOuts[1] >= minScyOut, "insufficient SCY out");
        }
    }

    function _callbackSwapExactPtForYt(
        address market,
        int256 ptToAccount,
        int256, /*scyToAccount*/
        bytes calldata data
    ) internal {
        unchecked {
            (address receiver, uint256 exactPtIn, uint256 minYtOut) = _decodeSwapExactPtForYt(
                data
            );
            uint256 netPtOwed = ptToAccount.abs();
            (, , IPYieldToken YT) = IPMarket(market).readTokens();

            uint256 netPyOut = YT.mintPY(market, receiver);
            require(netPyOut >= minYtOut, "insufficient YT out");
            require(exactPtIn + netPyOut >= netPtOwed, "insufficient PT to pay");
        }
    }

    function _callbackSwapExactYtForPt(
        address market,
        int256 ptToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        unchecked {
            (address receiver, uint256 exactYtIn, uint256 minPtOut) = _decodeSwapExactYtForPt(
                data
            );
            (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();

            uint256 netScyOwed = scyToAccount.abs();

            PT.safeTransfer(address(YT), exactYtIn);
            uint256 netScyToMarket = YT.redeemPY(market);

            require(netScyToMarket >= netScyOwed, "insufficient SCY to pay");
            require(ptToAccount.Uint() - exactYtIn >= minPtOut, "insufficient PT out");
            PT.safeTransfer(receiver, ptToAccount.Uint() - exactYtIn);
        }
    }
}
