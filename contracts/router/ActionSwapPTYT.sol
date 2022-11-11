// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../interfaces/IPActionSwapPTYT.sol";
import "../interfaces/IPMarket.sol";
import "./base/CallbackHelper.sol";

/// @dev All swap actions will fail if market is expired
contract ActionSwapPTYT is IPActionSwapPTYT, CallbackHelper, TokenHelper {
    using MarketMathCore for MarketState;
    using MarketApproxPtInLib for MarketState;
    using MarketApproxPtOutLib for MarketState;
    using Math for uint256;
    using Math for int256;
    using PYIndexLib for IPYieldToken;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor() //solhint-disable-next-line no-empty-blocks
    {

    }

    /**
     * @notice swap exact PT to YT with the help of flashswaps & YT tokenization / redemption
     * @dev inner working of this function:
     - `exactPtIn` PT is transferred to market contract
     - `market.swapExactPtForSy` is called, which will transfer SY directly to YT contract & callback is invoked.
        Note that we will owe PT, the amount before is not sufficient
     - in callback, all SY in YT contract is used to mint PT + YT, with PT used to pay the rest of the loan, and YT
        transferred to the receiver
     * @dev this function works in conjunction with ActionCallback
     */
    function swapExactPtForYt(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minYtOut,
        ApproxParams calldata guessTotalPtToSwap
    ) external returns (uint256 netYtOut, uint256 netSyFee) {
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();
        MarketState memory state = IPMarket(market).readState();

        _transferFrom(IERC20(PT), msg.sender, market, exactPtIn);

        uint256 totalPtToSwap;
        (netYtOut, totalPtToSwap, netSyFee) = state.approxSwapExactPtForYt(
            YT.newIndex(),
            exactPtIn,
            block.timestamp,
            guessTotalPtToSwap
        );

        if (netYtOut < minYtOut) revert Errors.RouterInsufficientYtOut(netYtOut, minYtOut);

        IPMarket(market).swapExactPtForSy(
            address(YT),
            totalPtToSwap,
            _encodeSwapExactPtForYt(receiver, exactPtIn, minYtOut)
        );

        emit SwapPtAndYt(msg.sender, market, receiver, exactPtIn.neg(), netYtOut.Int());
    }

    /**
     * @notice swap exact YT to PT with the help of flashswaps & YT tokenization / redemption
     * @dev inner working of this function:
     - `exactYtIn` YT is transferred to yield contract
     - `market.swapSyForExactPt` is called, which will transfer PT directly to this contract & callback is invoked.
        Note that we now owe SY
     - in callback, a portion of PT + YT is used to redeem SY, which is then used to payback the loan. The rest of 
       of the PT is transferred to `receiver`
     * @dev this function works in conjunction with ActionCallback
     */
    function swapExactYtForPt(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minPtOut,
        ApproxParams calldata guessTotalPtSwapped
    ) external returns (uint256 netPtOut, uint256 netSyFee) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        MarketState memory state = IPMarket(market).readState();

        _transferFrom(IERC20(YT), msg.sender, address(YT), exactYtIn);

        uint256 totalPtSwapped;
        (netPtOut, totalPtSwapped, netSyFee) = state.approxSwapExactYtForPt(
            YT.newIndex(),
            exactYtIn,
            block.timestamp,
            guessTotalPtSwapped
        );

        if (netPtOut < minPtOut) revert Errors.RouterInsufficientPtOut(netPtOut, minPtOut);

        IPMarket(market).swapSyForExactPt(
            address(this),
            totalPtSwapped,
            _encodeSwapExactYtForPt(receiver, exactYtIn, minPtOut)
        );

        emit SwapPtAndYt(msg.sender, market, receiver, netPtOut.Int(), exactYtIn.neg());
    }
}
