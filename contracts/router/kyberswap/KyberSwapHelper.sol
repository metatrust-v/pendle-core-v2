// SPDX-License-Identifier: GPL-3.0-or-later
/*
 * MIT License
 * ===========
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 */

pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "../../core/libraries/TokenHelper.sol";
import "./AggregationRouterHelper.sol";

struct TokenInput {
    address tokenIn;
    uint256 netTokenIn;
    address tokenMintSy;
    bytes kybercall;
    bool useBulkSeller;
}

struct TokenOutput {
    address tokenOut;
    uint256 minTokenOut;
    address tokenRedeemSy;
    bytes kybercall;
    bool useBulkSeller;
}

abstract contract KyberSwapHelper is TokenHelper {
    using Address for address;
    address public immutable kyberSwapRouter;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter) {
        kyberSwapRouter = _kyberSwapRouter;
    }

    function _kyberswap(
        address tokenIn,
        uint256 amountIn,
        bytes memory rawKybercall
    ) internal {
        _safeApproveInf(tokenIn, kyberSwapRouter);

        bytes memory kybercall = AggregationRouterHelper.getScaledInputData(
            rawKybercall,
            amountIn
        );
        kyberSwapRouter.functionCallWithValue(kybercall, tokenIn == NATIVE ? amountIn : 0);
    }
}
