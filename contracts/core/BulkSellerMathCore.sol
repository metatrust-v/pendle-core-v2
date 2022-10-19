// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./libraries/TokenHelper.sol";
import "./libraries/math/Math.sol";
import "./libraries/Errors.sol";

struct BulkSellerState {
    uint256 sellOutRate;
    uint256 buyInRate;
    uint256 totalToken;
    uint256 totalSy;
}

library BulkSellerMathCore {
    using Math for uint256;

    function swapExactTokenForSy(BulkSellerState memory state, uint256 exactTokenIn)
        internal
        pure
        returns (uint256 netSyOut)
    {
        netSyOut = exactTokenIn.mulDown(state.sellOutRate);

        if (netSyOut > state.totalSy)
            revert Errors.BulkInsufficientSyForTrade(state.totalSy, netSyOut);

        state.totalToken += exactTokenIn;
        state.totalSy -= netSyOut;
    }

    function swapExactSyForToken(BulkSellerState memory state, uint256 exactSyIn)
        internal
        pure
        returns (uint256 netTokenOut)
    {
        netTokenOut = exactSyIn.mulDown(state.buyInRate);

        if (netTokenOut > state.totalToken)
            revert Errors.BulkInsufficientTokenForTrade(state.totalToken, netTokenOut);

        state.totalSy += exactSyIn;
        state.totalToken -= netTokenOut;
    }

    function getTokenProportion(BulkSellerState memory state) internal pure returns (uint256) {
        uint256 totalToken = state.totalToken;
        uint256 totalTokenFromSy = state.totalSy.divDown(state.sellOutRate);
        return totalToken.divDown(totalToken + totalTokenFromSy);
    }

    function reBalance(BulkSellerState memory state, uint256 targetProportion)
        internal
        pure
        returns (uint256 netTokenToMint, uint256 netSyToRedeem)
    {
        uint256 currentProportion = getTokenProportion(state);

        if (currentProportion > targetProportion) {
            netTokenToMint = state.totalToken.mulDown(currentProportion - targetProportion);
        } else {
            netSyToRedeem = state.totalSy.mulDown(targetProportion - currentProportion);
        }
    }
}
