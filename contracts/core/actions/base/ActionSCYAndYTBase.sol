// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../../interfaces/IPMarketFactory.sol";
import "../../../interfaces/IPMarket.sol";
import "../../../SuperComposableYield/SCYUtils.sol";
import "../../../libraries/math/MarketApproxLib.sol";
import "../../../libraries/math/MarketMathAux.sol";
import "./ActionSCYAndYOBase.sol";
import "./ActionType.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ActionSCYAndYTBase is ActionSCYAndYOBase, ActionType {
    using Math for uint256;
    using Math for int256;
    using MarketMathCore for MarketState;
    using MarketMathAux for MarketState;
    using MarketApproxLib for MarketState;
    using SafeERC20 for ISuperComposableYield;
    using SafeERC20 for IPYieldToken;

    event SwapYT(
        address indexed user,
        int256 ytToAccount,
        int256 scyToAccount
    );

    function _swapExactScyForYt(
        address receiver,
        address market,
        uint256 exactScyIn,
        ApproxParams memory approx,
        bool doPull
    ) internal returns (uint256 netYtOut) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();
        MarketState memory state = IPMarket(market).readState(false);

        (netYtOut, ) = state.approxSwapExactScyForYt(
            SCYIndexLib.newIndex(SCY),
            exactScyIn,
            block.timestamp,
            approx
        );

        if (doPull) {
            SCY.safeTransferFrom(msg.sender, address(YT), exactScyIn);
        }

        IPMarket(market).swapExactOtForScy(
            address(YT),
            netYtOut, // exactOtIn = netYtOut
            1,
            abi.encode(ACTION_TYPE.SwapExactScyForYt, receiver)
        );

        emit SwapYT(receiver, netYtOut.Int(), exactScyIn.neg());
    }

    /**
    * @dev inner working of this function:
     - YT is transferred to the YT contract
     - market.swap is called, which will transfer OT directly to the YT contract, and callback is invoked
     - callback will call YT's redeemYO, which will redeem the outcome SCY to this router, then
        all SCY owed to the market will be paid, the rest is transferred to the receiver
     */
    function _swapExactYtForScy(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minScyOut,
        bool doPull
    ) internal returns (uint256 netScyOut) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 preBalanceScy = SCY.balanceOf(receiver);

        if (doPull) {
            YT.safeTransferFrom(msg.sender, address(YT), exactYtIn);
        }

        IPMarket(market).swapScyForExactOt(
            address(YT),
            exactYtIn, // exactOtOut = exactYtIn
            type(uint256).max,
            abi.encode(ACTION_TYPE.SwapExactYtForScy, receiver)
        );

        netScyOut = SCY.balanceOf(receiver) - preBalanceScy;
        require(netScyOut >= minScyOut, "INSUFFICIENT_SCY_OUT");

        emit SwapYT(receiver, exactYtIn.neg(), netScyOut.Int());
    }

    /**
     * @dev inner working of this function:
     - market.swap is called, which will transfer SCY directly to the YT contract, and callback is invoked
     - callback will pull more SCY if necessary, do call YT's mintYO, which will mint OT to the market & YT to the receiver
     */
    function _swapScyForExactYt(
        address receiver,
        address market,
        uint256 exactYtOut,
        uint256 maxScyIn
    ) internal returns (uint256 netScyIn) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        uint256 preBalanceScy = SCY.balanceOf(receiver);

        IPMarket(market).swapExactOtForScy(
            address(YT),
            exactYtOut, // exactOtIn = exactYtOut
            1,
            abi.encode(ACTION_TYPE.SwapSCYForExactYt, msg.sender, receiver)
        );

        netScyIn = preBalanceScy - SCY.balanceOf(receiver);

        require(netScyIn <= maxScyIn, "exceed out limit");

        emit SwapYT(receiver, exactYtOut.Int(), netScyIn.neg());
    }

    function _swapYtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        ApproxParams memory approx,
        bool doPull
    ) internal returns (uint256 netYtIn) {
        MarketState memory state = IPMarket(market).readState(false);
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        (netYtIn, ) = state.approxSwapYtForExactScy(
            SCYIndexLib.newIndex(SCY),
            exactScyOut,
            block.timestamp,
            approx
        );

        if (doPull) {
            YT.safeTransferFrom(msg.sender, address(YT), netYtIn);
        }

        IPMarket(market).swapScyForExactOt(
            address(YT),
            netYtIn, // exactOtOut = netYtIn
            type(uint256).max,
            abi.encode(ACTION_TYPE.SwapYtForExactScy, receiver)
        );

        emit SwapYT(receiver, netYtIn.neg(), exactScyOut.Int());
    }
}
