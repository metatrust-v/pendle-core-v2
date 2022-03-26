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

pragma solidity ^0.8.0;
import "openzeppelin-solidity/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ILiquidYieldToken is IERC20Metadata {
    function mint(
        address recipient,
        address baseTokenIn,
        uint256 minAmountLytOut
    ) external returns (uint256 amountLytOut);

    function redeem(
        address recipient,
        address baseTokenOut,
        uint256 minAmountBaseOut
    ) external returns (uint256 amountBaseOut);

    function assetBalanceOf(address user) external returns (uint256);

    function updateGlobalReward() external;

    function updateUserReward(address user) external;

    function redeemReward(address user) external returns (uint256[] memory outAmounts);

    function lytIndexCurrent() external returns (uint256);

    function lytIndexStored() external view returns (uint256);

    function getBaseTokens() external view returns (address[] memory);

    function isValidBaseToken(address token) external view returns (bool);

    function getRewardTokens() external view returns (address[] memory);

    function assetDecimals() external view returns (uint8);
}
