// SPDX-License-Identifier: MIT
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

import "./PendleLiquidYieldToken.sol";
import "../interfaces/IPendleYieldContractDeployer.sol";
import "../libraries/helpers/ExpiryUtilsLib.sol";
import "../libraries/helpers/TrioTokensLib.sol";
import "../tokens/PendleOwnershipToken.sol";
import "../tokens/PendleYieldToken.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";

struct YOToken {
    PendleOwnershipToken OT;
    PendleYieldToken YT;
}

struct YieldData {
    YOToken yoToken;
    // interest-related
    uint256 lastRateBeforeExpiry;
    mapping(address => uint256) lastRate;
    mapping(address => uint256) dueInterests;
    // reward-related
    TrioUints paramL;
    TrioUints rewardReserves;
    mapping(address => TrioUints) lastParamL;
    mapping(address => TrioUints) dueRewards;
}

// solhint-disable func-param-name-mixedcase, var-name-mixedcase
contract PendleForgeBase {
    using ExpiryUtils for string;
    using TrioTokensLib for TrioUints;
    using TrioTokensLib for TrioTokens;
    using FixedPoint for uint256;

    string public constant OT_PREFIX = "OT";
    string public constant YT_PREFIX = "YT";

    IPendleYieldContractDeployer public immutable yieldContractDeployer;

    mapping(PendleLiquidYieldToken => mapping(uint256 => YieldData)) public yieldData;

    constructor(IPendleYieldContractDeployer _yieldContractDeployer) {
        yieldContractDeployer = _yieldContractDeployer;
    }

    function newYieldContracts(PendleLiquidYieldToken LYT, uint256 expiry) external returns (YOToken memory yo) {
        uint8 yieldTokenDecimals = ERC20(address(LYT)).decimals();

        yo.OT = yieldContractDeployer.forgeOwnershipToken(
            LYT,
            OT_PREFIX.concat(ERC20(address(LYT)).name(), expiry, " "),
            OT_PREFIX.concat(ERC20(address(LYT)).symbol(), expiry, "-"),
            yieldTokenDecimals,
            expiry
        );

        yo.YT = yieldContractDeployer.forgeFutureYieldToken(
            LYT,
            YT_PREFIX.concat(ERC20(address(LYT)).name(), expiry, " "),
            YT_PREFIX.concat(ERC20(address(LYT)).symbol(), expiry, "-"),
            yieldTokenDecimals,
            expiry
        );

        yieldData[LYT][expiry].yoToken = yo;
    }

    function redeemUnderlying(
        PendleLiquidYieldToken LYT,
        uint256 expiry,
        uint256 amount,
        address user
    ) external {
        YieldData storage data = yieldData[LYT][expiry];
        PendleOwnershipToken OT = PendleOwnershipToken(data.yoToken.OT);
        PendleYieldToken YT = PendleYieldToken(data.yoToken.YT);

        bool isYTExpired = (expiry < block.timestamp);
        uint256 redeemedAmount;
        if (isYTExpired) {
            OT.burn(user, amount);
        } else {
            OT.burn(user, amount);
            YT.burn(user, amount);
        }

        redeemedAmount = _calcAmountRedeemable(LYT, expiry, amount);
        redeemedAmount += _beforeTransferDueInterests(LYT, expiry, user, true);

        TrioUints memory rewardAmounts = _beforeTransferDueRewards(LYT, expiry, user);

        TrioTokens memory rewardTokens = LYT.getRewardTokens();

        rewardTokens.safeTransfer(user, rewardAmounts);
        LYT.transfer(user, redeemedAmount);
    }

    function redeemDueInterest(
        PendleLiquidYieldToken LYT,
        uint256 expiry,
        address user
    ) external {
        uint256 redeemedAmount = _beforeTransferDueInterests(LYT, expiry, user, false);
        LYT.transfer(user, redeemedAmount);
    }

    function tokenizeYield(
        PendleLiquidYieldToken LYT,
        uint256 expiry,
        uint256 amount,
        address to
    ) external {
        YieldData storage data = yieldData[LYT][expiry];
        PendleOwnershipToken OT = data.yoToken.OT;
        PendleYieldToken YT = data.yoToken.YT;

        LYT.transferFrom(msg.sender, address(this), amount);

        uint256 amountToMint = _calcAmountToMint(LYT, expiry, amount);

        OT.mint(to, amountToMint);
        YT.mint(to, amountToMint);
    }

    function _calcAmountRedeemable(
        PendleLiquidYieldToken LYT,
        uint256 expiry,
        uint256 amount
    ) internal returns (uint256 totalAfterExpiry) {
        totalAfterExpiry = amount.divDown(getExchangeRateBeforeExpiry(LYT, expiry));
    }

    function _calcAmountToMint(
        PendleLiquidYieldToken LYT,
        uint256 expiry,
        uint256 amount
    ) internal returns (uint256 amountToMint) {
        amountToMint = amount.mulDown(getExchangeRateBeforeExpiry(LYT, expiry));
    }

    function _beforeTransferDueInterests(
        PendleLiquidYieldToken LYT,
        uint256 expiry,
        address user,
        bool skipUpdate
    ) internal virtual returns (uint256 amountOut) {
        if (!skipUpdate) {
            _updateDueInterests(LYT, expiry, user);
        }

        amountOut = yieldData[LYT][expiry].dueInterests[user];
        yieldData[LYT][expiry].dueInterests[user] = 0;
    }

    function _beforeTransferDueRewards(
        PendleLiquidYieldToken LYT,
        uint256 expiry,
        address user
    ) internal returns (TrioUints memory rewardAmounts) {
        _updateDueRewards(LYT, expiry, user);

        YieldData storage data = yieldData[LYT][expiry];

        rewardAmounts = data.dueRewards[user];
        data.dueRewards[user] = TrioUints(0, 0, 0);

        data.rewardReserves = data.rewardReserves.sub(rewardAmounts);
    }

    function getExchangeRateBeforeExpiry(PendleLiquidYieldToken LYT, uint256 expiry)
        internal
        returns (uint256 exchangeRate)
    {
        YieldData storage data = yieldData[LYT][expiry];
        if (block.timestamp > expiry) {
            return data.lastRateBeforeExpiry;
        }
        exchangeRate = LYT.exchangeRateCurrent();
        data.lastRateBeforeExpiry = exchangeRate;
    }

    /**
    @dev same logic as UniswapV2's Forge
     */
    function _updateDueInterests(
        PendleLiquidYieldToken LYT,
        uint256 expiry,
        address user
    ) internal {
        YieldData storage data = yieldData[LYT][expiry];
        PendleYieldToken YT = data.yoToken.YT;
        uint256 prevRate = data.lastRate[user];
        uint256 currentRate = getExchangeRateBeforeExpiry(LYT, expiry);
        uint256 principal = YT.balanceOf(user);

        data.lastRate[user] = currentRate;
        // first time getting YT, or there is no update in exchangeRate
        if (prevRate == 0 || prevRate == currentRate) {
            return;
        }

        uint256 interestFromYT = (principal * (currentRate - prevRate)).divDown(prevRate * currentRate);

        data.dueInterests[user] = data.dueInterests[user].add(interestFromYT);
    }

    function _updateDueRewards(
        PendleLiquidYieldToken LYT,
        uint256 expiry,
        address user
    ) internal {
        _updateParamL(LYT, expiry);

        YieldData storage data = yieldData[LYT][expiry];
        TrioUints memory userLastParamL = data.lastParamL[user];

        if (userLastParamL.allZero()) {
            data.lastParamL[user] = data.paramL;
            return;
        }

        if (userLastParamL.eq(data.paramL)) {
            return;
        }

        PendleYieldToken YT = data.yoToken.YT;

        uint256 principal = YT.balanceOf(user);
        TrioUints memory rewardsAmountPerYT = data.paramL.sub(userLastParamL);

        TrioUints memory rewardsFromYT = rewardsAmountPerYT.mulDown(principal);
        data.dueRewards[user] = data.dueRewards[user].add(rewardsFromYT);
        data.lastParamL[user] = data.paramL;
        // update rewardBalance
    }

    function _updateParamL(PendleLiquidYieldToken LYT, uint256 expiry) internal {
        YieldData storage data = yieldData[LYT][expiry];

        if (data.paramL.allZero()) {
            // paramL always starts from 1, to make sure that if a user's lastParamL is 0,
            // they must be getting OT for the very first time, and we will know it in _updatePendingRewards()
            data.paramL = TrioUints(1, 1, 1);
        }

        TrioUints memory incomeRewards = LYT.redeemReward();

        PendleYieldToken YT = data.yoToken.YT;

        uint256 totalYT = YT.totalSupply();

        TrioUints memory incomeRewardsPerYT;
        if (totalYT != 0) {
            incomeRewardsPerYT = incomeRewards.mul(FixedPoint.ONE).divDown(totalYT);
        }

        // Update new states
        data.paramL = data.paramL.add(incomeRewardsPerYT);
        data.rewardReserves = data.rewardReserves.add(incomeRewards);
    }
}
