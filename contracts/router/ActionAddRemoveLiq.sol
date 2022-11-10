// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./base/ActionBaseMintRedeem.sol";
import "../interfaces/IPActionAddRemoveLiq.sol";
import "../interfaces/IPMarket.sol";
import "../core/libraries/Errors.sol";

/**
 * @dev If market is expired, all actions will fail, except for the following:
 * - removeLiquidityDualSyAndPt()
 * - removeLiquidityDualTokenAndPt()
 * - removeLiquiditySingleSy()
 * - removeLiquiditySingleToken()
 * This is because swapping and providing liquidity are not allowed on an expired market.
 */

contract ActionAddRemoveLiq is IPActionAddRemoveLiq, ActionBaseMintRedeem {
    using Math for uint256;
    using Math for int256;
    using MarketMathCore for MarketState;
    using MarketApproxPtInLib for MarketState;
    using MarketApproxPtOutLib for MarketState;
    using SafeERC20 for IERC20;
    using PYIndexLib for IPYieldToken;
    using BulkSellerMathCore for BulkSellerState;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberScalingLib, address _bulkSellerDirectory)
        ActionBaseMintRedeem(_kyberScalingLib, _bulkSellerDirectory) //solhint-disable-next-line no-empty-blocks
    {}

    /**
     * @notice Adds liquidity to the SY/PT market, granting LP tokens in return
     * @dev Will mint as much LP as possible given no more than `netSyDesired` and `netPtDesired`,
     * while not changing the market's price
     * @dev Only the necessary SY/PT amount will be transferred
     * @dev Fails if market is expired
     */
    function addLiquidityDualSyAndPt(
        address receiver,
        address market,
        uint256 netSyDesired,
        uint256 netPtDesired,
        uint256 minLpOut
    )
        external
        returns (
            uint256 netLpOut,
            uint256 netSyUsed,
            uint256 netPtUsed
        )
    {
        (IStandardizedYield SY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        // calculate the amount of SY and PT to be used
        MarketState memory state = IPMarket(market).readState();
        (, netLpOut, netSyUsed, netPtUsed) = state.addLiquidity(
            netSyDesired,
            netPtDesired,
            block.timestamp
        );

        // early-check
        if (netLpOut < minLpOut) revert Errors.RouterInsufficientLpOut(netLpOut, minLpOut);

        // execute the addLiquidity
        IERC20(SY).safeTransferFrom(msg.sender, market, netSyUsed);
        IERC20(PT).safeTransferFrom(msg.sender, market, netPtUsed);

        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyUsed, netPtUsed);

        // fail-safe
        if (netLpOut < minLpOut) assert(false);

        emit AddLiquidityDualSyAndPt(msg.sender, market, receiver, netSyUsed, netPtUsed, netLpOut);
    }

    /**
     * @notice Adds liquidity to SY/PT market using PT and any ERC20 token
     * @dev Input token is first swapped to SY-mintable token, then SY is minted from such
     * Finally the SY/PT pair is added to the market
     * @param input data for input token, see {`./kyberswap/KyberSwapHelper.sol`}
     * @param netPtDesired maximum PT to be used
     * @dev Only the necessary PT amount will be transferred
     * @dev Fails if TokenInput.netTokenIn = netTokenUsed (i.e. all SY minted must be used)
     * @dev Fails if market is expired
     */
    function addLiquidityDualTokenAndPt(
        address receiver,
        address market,
        TokenInput calldata input,
        uint256 netPtDesired,
        uint256 minLpOut
    )
        external
        payable
        returns (
            uint256 netLpOut,
            uint256 netTokenUsed,
            uint256 netPtUsed
        )
    {
        (IStandardizedYield SY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        uint256 netSyDesired = _mintSyFromToken(market, address(SY), 1, input);
        uint256 netSyUsed;

        {
            // calc the amount of SY and PT to be used
            MarketState memory state = IPMarket(market).readState();
            (, netLpOut, netSyUsed, netPtUsed) = state.addLiquidity(
                netSyDesired,
                netPtDesired,
                block.timestamp
            );

            if (netSyDesired != netSyUsed)
                revert Errors.RouterNotAllSyUsed(netSyDesired, netSyUsed);
            if (netLpOut < minLpOut) revert Errors.RouterInsufficientLpOut(netLpOut, minLpOut);

            netTokenUsed = input.netTokenIn;
        }

        // SY has been minted and transferred to the market
        IERC20(PT).safeTransferFrom(msg.sender, market, netPtUsed);
        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyUsed, netPtUsed);

        // fail-safe
        if (netLpOut < minLpOut) assert(false);

        emit AddLiquidityDualTokenAndPt(
            msg.sender,
            market,
            receiver,
            input.tokenIn,
            netTokenUsed,
            netPtUsed,
            netLpOut
        );
    }

    /**
     * @notice Swaps partial PT to SY, then use them to add liquidity to SY/PT pair
     * @param netPtIn amount of PT to be transferred in from caller
     * @param guessPtSwapToSy approximate info for the swap
     * @return netSyFee amount of SY fee incurred from the swap
     * @dev Fails if market is expired
     */
    function addLiquiditySinglePt(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtSwapToSy
    ) external returns (uint256 netLpOut, uint256 netSyFee) {
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();

        // calculate the amount of PT to swap
        MarketState memory state = IPMarket(market).readState();

        (uint256 netPtSwap, , ) = state.approxSwapPtToAddLiquidity(
            YT.newIndex(),
            netPtIn,
            block.timestamp,
            guessPtSwapToSy
        );

        // execute the swap
        IERC20(PT).safeTransferFrom(msg.sender, market, netPtIn);

        uint256 netSyReceived;
        (netSyReceived, netSyFee) = IPMarket(market).swapExactPtForSy(
            market,
            netPtSwap,
            EMPTY_BYTES
        );

        // execute the addLiquidity
        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyReceived, netPtIn - netPtSwap);

        if (netLpOut < minLpOut) revert Errors.RouterInsufficientLpOut(netLpOut, minLpOut);

        emit AddLiquiditySinglePt(msg.sender, market, receiver, netPtIn, netLpOut);
    }

    /**
     * @notice Swaps partial SY to PT, then use them to add liquidity to SY/PT pair
     * @param netSyIn amount of SY to be transferred in from caller
     * @param guessPtReceivedFromSy approx. output PT from the swap
     * @return netSyFee amount of SY fee incurred from the swap
     * @dev Fails if market is expired
     */
    function addLiquiditySingleSy(
        address receiver,
        address market,
        uint256 netSyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromSy
    ) external returns (uint256 netLpOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        // transfer SY to market
        IERC20(SY).safeTransferFrom(msg.sender, market, netSyIn);

        // mint LP
        (netLpOut, netSyFee) = _addLiquiditySingleSy(
            receiver,
            market,
            YT,
            netSyIn,
            minLpOut,
            guessPtReceivedFromSy
        );

        emit AddLiquiditySingleSy(msg.sender, market, receiver, netSyIn, netLpOut);
    }

    /**
     * @notice Adds liquidity using a single token input.
     * @dev Inner workings of this function:
        - (If needed) input token is swapped to SY-mintable token
        - SY is minted from resulting tokens
        - Partial SY is swapped to PT using the market itself
        - The resulting SY/PT amount is used to add liquidity.
     * @param guessPtReceivedFromSy approximate PT output for the swap
     * @param input data for input token, see {`./kyberswap/KyberSwapHelper.sol`}
     * @return netSyFee amount of SY fee incurred from the swap
     * @dev Fails if market is expired
     */
    function addLiquiditySingleToken(
        address receiver,
        address market,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromSy,
        TokenInput calldata input
    ) external payable returns (uint256 netLpOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        // mint SY directly to the market
        uint256 netSyUsed = _mintSyFromToken(market, address(SY), 1, input);

        // mint LP
        (netLpOut, netSyFee) = _addLiquiditySingleSy(
            receiver,
            market,
            YT,
            netSyUsed,
            minLpOut,
            guessPtReceivedFromSy
        );

        emit AddLiquiditySingleToken(
            msg.sender,
            market,
            input.tokenIn,
            receiver,
            input.netTokenIn,
            netLpOut
        );
    }

    /**
     * @notice Burns LP token to remove SY/PT liquidity
     * @param netLpToRemove amount of LP to be burned from caller
     * @dev Will work even if market is expired
     */
    function removeLiquidityDualSyAndPt(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minSyOut,
        uint256 minPtOut
    ) external returns (uint256 netSyOut, uint256 netPtOut) {
        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        (netSyOut, netPtOut) = IPMarket(market).burn(receiver, receiver, netLpToRemove);

        if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut);
        if (netPtOut < minPtOut) revert Errors.RouterInsufficientPtOut(netPtOut, minPtOut);

        emit RemoveLiquidityDualSyAndPt(
            msg.sender,
            market,
            receiver,
            netLpToRemove,
            netPtOut,
            netSyOut
        );
    }

    /**
     * @notice Burns LP token to remove SY/PT liquidity, then redeems SY, finally (if needed)
     * swaps to desired output token
     * @param netLpToRemove amount of LP to be burned from caller
     * @param output data for desired output token, see {`./kyberswap/KyberSwapHelper.sol`}
     * @dev Will work even if market is expired
     */
    function removeLiquidityDualTokenAndPt(
        address receiver,
        address market,
        uint256 netLpToRemove,
        TokenOutput calldata output,
        uint256 minPtOut
    ) external returns (uint256 netTokenOut, uint256 netPtOut) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();

        // burn LP, SY sent to either SY or bulk, PT sent to receiver
        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        uint256 netSyOut;
        (netSyOut, netPtOut) = IPMarket(market).burn(
            _syOrBulk(address(SY), output),
            receiver,
            netLpToRemove
        );

        if (netPtOut < minPtOut) revert Errors.RouterInsufficientPtOut(netPtOut, minPtOut);

        // redeem SY to token
        netTokenOut = _redeemSyToToken(receiver, address(SY), netSyOut, output, false);

        emit RemoveLiquidityDualTokenAndPt(
            msg.sender,
            market,
            receiver,
            netLpToRemove,
            netPtOut,
            output.tokenOut,
            netTokenOut
        );
    }

    /**
     * @notice Removes SY/PT liquidity, then swaps all resulting SY to return only PT
     * @param netLpToRemove amount of LP to be burned from caller
     * @param guessPtOut approximate info for the swap only (not for the total PT)
     * @return netSyFee amount of SY fee incurred from the swap
     * @dev Fails if market is expired
     */
    function removeLiquiditySinglePt(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut
    ) external returns (uint256 netPtOut, uint256 netSyFee) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();

        // calculate the total amount of PT received from burning & selling SY
        MarketState memory state = IPMarket(market).readState();
        (uint256 syFromBurn, uint256 ptFromBurn) = state.removeLiquidity(netLpToRemove);
        (uint256 ptFromSwap, ) = state.approxSwapExactSyForPt(
            YT.newIndex(),
            syFromBurn,
            block.timestamp,
            guessPtOut
        );

        if (ptFromBurn + ptFromSwap < minPtOut)
            revert Errors.RouterInsufficientPtOut(ptFromBurn + ptFromSwap, minPtOut);

        // execute the burn & the swap
        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        (, ptFromBurn) = IPMarket(market).burn(market, receiver, netLpToRemove);
        (, netSyFee) = IPMarket(market).swapSyForExactPt(receiver, ptFromSwap, EMPTY_BYTES);

        netPtOut = ptFromBurn + ptFromSwap;

        // fail-safe
        if (netPtOut < minPtOut) assert(false);

        emit RemoveLiquiditySinglePt(msg.sender, market, receiver, netLpToRemove, netPtOut);
    }

    /**
     * @notice Removes SY/PT liquidity, then converts all resulting PT to return only SY
     * @dev Conversion is done with market swap if not expired, or with PT redeeming if expired
     * @param netLpToRemove amount of LP to be burned from caller
     * @return netSyFee amount of SY fee incurred from the swap
     * @dev Will work even if market is expired
     */
    function removeLiquiditySingleSy(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minSyOut
    ) external returns (uint256 netSyOut, uint256 netSyFee) {
        // transfer LP to market
        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        // burn LP, SY sent to receiver
        (netSyOut, netSyFee) = _removeLiquiditySingleSy(receiver, market, netLpToRemove, minSyOut);

        emit RemoveLiquiditySingleSy(msg.sender, market, receiver, netLpToRemove, netSyOut);
    }

    /**
     * @notice Removes SY/PT liquidity, then converts all to desired output token.
     * @dev inner workings of this function:
        - SY/PT liquidity is removed
        - If market is not expired, swaps PT to SY, else burns PT to redeem SY
        - Redeems assets by burning SY
        - (If needed) swaps resulting assets to output token
     * @param netLpToRemove amount of LP to be burned from caller
     * @param output data for desired output token, see {`./kyberswap/KyberSwapHelper.sol`}
     * @return netSyFee amount of SY fee incurred from the swap
     * @dev Will work even if market is expired
     */
    function removeLiquiditySingleToken(
        address receiver,
        address market,
        uint256 netLpToRemove,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netSyFee) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();

        // transfer LP to market, burn LP, SY sent to either SY or bulk
        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        uint256 netSyReceived;

        (netSyReceived, netSyFee) = _removeLiquiditySingleSy(
            _syOrBulk(address(SY), output),
            market,
            netLpToRemove,
            1
        );

        // redeem SY to token
        netTokenOut = _redeemSyToToken(receiver, address(SY), netSyReceived, output, false);

        emit RemoveLiquiditySingleToken(
            msg.sender,
            market,
            output.tokenOut,
            receiver,
            netLpToRemove,
            netTokenOut
        );
    }

    /// @dev swaps SY to PT, then adds liquidity
    function _addLiquiditySingleSy(
        address receiver,
        address market,
        IPYieldToken YT,
        uint256 netSyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromSy
    ) internal returns (uint256 netLpOut, uint256 netSyFee) {
        MarketState memory state = IPMarket(market).readState();

        // calculate the PT amount needed to add liquidity
        (uint256 netPtFromSwap, , ) = state.approxSwapSyToAddLiquidity(
            YT.newIndex(),
            netSyIn,
            block.timestamp,
            guessPtReceivedFromSy
        );

        // execute the swap & the addLiquidity
        uint256 netSySwapped;
        (netSySwapped, netSyFee) = IPMarket(market).swapSyForExactPt(
            market,
            netPtFromSwap,
            EMPTY_BYTES
        );

        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyIn - netSySwapped, netPtFromSwap);

        if (netLpOut < minLpOut) revert Errors.RouterInsufficientLpOut(netLpOut, minLpOut);
    }

    /// @dev removes SY/PT liquidity, then converts PT to SY
    function _removeLiquiditySingleSy(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minSyOut
    ) internal returns (uint256 netSyOut, uint256 netSyFee) {
        if (IPMarket(market).isExpired()) {
            netSyOut = __removeLpToSyAfterExpiry(receiver, market, netLpToRemove);
        } else {
            (netSyOut, netSyFee) = __removeLpToSyBeforeExpiry(receiver, market, netLpToRemove);
        }

        if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut);
    }

    /// @dev converts PT to SY post-expiry
    function __removeLpToSyAfterExpiry(
        address receiver,
        address market,
        uint256 netLpToRemove
    ) internal returns (uint256 netSyOut) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        (uint256 syFromBurn, ) = IPMarket(market).burn(receiver, address(YT), netLpToRemove);
        netSyOut = syFromBurn + IPYieldToken(YT).redeemPY(receiver);
    }

    /// @dev swaps PT to SY pre-expiry
    function __removeLpToSyBeforeExpiry(
        address receiver,
        address market,
        uint256 netLpToRemove
    ) internal returns (uint256 netSyOut, uint256 netSyFee) {
        (uint256 syFromBurn, uint256 ptFromBurn) = IPMarket(market).burn(
            receiver,
            market,
            netLpToRemove
        );

        uint256 syFromSwap;
        (syFromSwap, netSyFee) = IPMarket(market).swapExactPtForSy(
            receiver,
            ptFromBurn,
            EMPTY_BYTES
        );

        netSyOut = syFromBurn + syFromSwap;
    }
}
