// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPMarketAddRemoveCallback.sol";
import "../../interfaces/IPMarketSwapCallback.sol";
import "../../SuperComposableYield/SCYUtils.sol";
import "../../libraries/math/MarketApproxLib.sol";
import "../../libraries/math/MarketMathAux.sol";
import "./base/ActionSCYAndPYBase.sol";
import "./base/ActionType.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ActionCallback is IPMarketSwapCallback, IPMarketAddRemoveCallback, ActionType {
    address public immutable marketFactory;
    using Math for int256;
    using Math for uint256;
    using SafeERC20 for ISuperComposableYield;
    using SafeERC20 for IPYieldToken;
    using SafeERC20 for IPPrincipalToken;
    using SafeERC20 for IPMarket;

    modifier onlyPendleMarket(address market) {
        require(IPMarketFactory(marketFactory).isValidMarket(market), "INVALID_MARKET");
        _;
    }

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _marketFactory) {
        require(_marketFactory != address(0), "zero address");
        marketFactory = _marketFactory;
    }

    function addLiquidityCallback(
        uint256, /*lpToAccount*/
        uint256 scyOwed,
        uint256 ptOwed,
        bytes calldata data
    ) external onlyPendleMarket(msg.sender) {
        address market = msg.sender;
        address payer = abi.decode(data, (address));
        (ISuperComposableYield SCY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();
        SCY.safeTransferFrom(payer, market, scyOwed);
        PT.safeTransferFrom(payer, market, ptOwed);
    }

    function removeLiquidityCallback(
        uint256 lpOwed,
        uint256, /*scyToAccount*/
        uint256, /*ptToAccount*/
        bytes calldata data
    ) external onlyPendleMarket(msg.sender) {
        address market = msg.sender;
        address payer = abi.decode(data, (address));
        IPMarket(market).safeTransferFrom(payer, market, lpOwed);
    }

    /**
     * @dev The callback is only callable by a Pendle Market created by the factory
     */
    function swapCallback(
        int256 ptToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) external override onlyPendleMarket(msg.sender) {
        (ACTION_TYPE actionType, ) = abi.decode(data, (ACTION_TYPE, address));
        if (actionType == ACTION_TYPE.SwapExactPtForScy) {
            _basicSwap_callback(msg.sender, ptToAccount, scyToAccount, data);
        } else if (actionType == ACTION_TYPE.SwapScyForExactPt) {
            _basicSwap_callback(msg.sender, ptToAccount, scyToAccount, data);
        } else if (actionType == ACTION_TYPE.SwapExactScyForYt) {
            _swapExactScyForYt_callback(msg.sender, ptToAccount, scyToAccount, data);
        } else if (actionType == ACTION_TYPE.SwapSCYForExactYt) {
            _swapScyForExactYt_callback(msg.sender, ptToAccount, scyToAccount, data);
        } else if (
            actionType == ACTION_TYPE.SwapYtForExactScy ||
            actionType == ACTION_TYPE.SwapExactYtForScy
        ) {
            _swapYtForScy_callback(msg.sender, ptToAccount, scyToAccount, data);
        } else {
            require(false, "unknown actionType");
        }
    }

    function _basicSwap_callback(
        address market,
        int256 ptToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        (, address payer) = abi.decode(data, (ACTION_TYPE, address));
        (ISuperComposableYield SCY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();
        if (ptToAccount > 0) PT.safeTransferFrom(payer, market, ptToAccount.Uint());
        if (scyToAccount > 0) SCY.safeTransferFrom(payer, market, ptToAccount.Uint());
    }

    function _swapExactScyForYt_callback(
        address market,
        int256 ptToAccount,
        int256, /*scyToAccount*/
        bytes calldata data
    ) internal {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        (, address receiver) = abi.decode(data, (ACTION_TYPE, address));

        uint256 ptOwed = ptToAccount.abs();
        uint256 amountPYout = YT.mintPY(market, receiver);

        require(amountPYout >= ptOwed, "insufficient pt to pay");
    }

    function _swapScyForExactYt_callback(
        address market,
        int256 ptToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        (, address payer, address receiver) = abi.decode(data, (ACTION_TYPE, address, address));
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 ptOwed = ptToAccount.neg().Uint();
        uint256 scyReceived = scyToAccount.Uint();

        // ptOwed = totalAsset
        uint256 scyIndex = SCY.scyIndexCurrent();
        uint256 scyNeedTotal = SCYUtils.assetToScy(scyIndex, ptOwed);
        scyNeedTotal += scyIndex.rawDivUp(SCYUtils.ONE);

        {
            uint256 netScyToPull = scyNeedTotal.subMax0(scyReceived);
            SCY.safeTransferFrom(payer, address(YT), netScyToPull);
        }

        uint256 amountPYout = YT.mintPY(market, receiver);

        require(amountPYout >= ptOwed, "insufficient pt to pay");
    }

    /**
    @dev receive PT -> pair with YT to redeem SCY -> payback SCY
    */
    function _swapYtForScy_callback(
        address market,
        int256, /*ptToAccount*/
        int256 scyToAccount,
        bytes calldata data
    ) internal {
        (, address receiver) = abi.decode(data, (ACTION_TYPE, address));
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 scyOwed = scyToAccount.neg().Uint();

        uint256 netScyReceived = YT.redeemPY(address(this));

        SCY.safeTransfer(market, scyOwed);

        if (receiver != address(this)) {
            SCY.safeTransfer(receiver, netScyReceived - scyOwed);
        }
    }
}
