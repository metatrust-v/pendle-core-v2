// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "./Math.sol";
import "./MarketMathCore.sol";
import "./MarketMathCore.sol";

struct ApproxParams {
    uint256 guessMin;
    uint256 guessMax;
    uint256 guessOffchain; // pass 0 in to skip this variable
    uint256 maxIteration; // every iteration, the diff between guessMin and guessMax will be divided by 2
    uint256 eps; // the max eps between the returned result & the correct result, base 1e18. Normally this number will be set
    // to 1e15 (1e18/1000 = 0.1%)

    /// Further explanation of the eps. Take swapExactScyForPt for example. To calc the corresponding amount of Pt to swap out,
    /// it's necessary to run an approximation algorithm, because by default there only exists the Pt to Scy formula
    /// To approx, the 5 values above will have to be provided, and the approx process will run as follows:
    /// mid = (guessMin + guessMax) / 2 // mid here is the current guess of the amount of Pt out
    /// netScyNeed = calcSwapScyForExactPt(mid)
    /// if (netScyNeed > exactScyIn) guessMax = mid - 1 // since the maximum Scy in can't exceed the exactScyIn
    /// else guessMin = mid (1)
    /// For the (1), since netScyNeed <= exactScyIn, the result might be usable. If the netScyNeed is within eps of
    /// exactScyIn (ex eps=0.1% => we have used 99.9% the amount of Scy specified), mid will be chosen as the final guess result

    /// for guessOffchain, this is to provide a shortcut to guessing. The offchain SDK can precalculate the exact result
    /// before the tx is sent. When the tx reaches the contract, the guessOffchain will be checked first, and if it satisfies the
    /// approximation, it will be used (and save all the guessing).
}

// solhint-disable reason-string, ordering
library MarketApproxLib {
    using Math for uint256;
    using Math for int256;
    using LogExpMath for int256;
    using SCYIndexLib for SCYIndex;
    using MarketMathCore for MarketState;

    struct VarsSwapPtForExactScy {
        uint256 netPtInGuess;
        int256 assetToAccount;
        uint256 netAssetOut;
        uint256 minAssetOut;
        uint256 largestGoodSlope;
        bool isSlopeNonNeg;
    }

    /// `guessMin` & `guessMax` is to guess the `netPtIn`

    function approxSwapPtForExactScy(
        MarketState memory market,
        SCYIndex index,
        uint256 minScyOut,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        pure
        returns (
            uint256, /*netPtIn*/
            uint256 /*netScyOut*/
        )
    {
        /*
        the algorithm is essentially to:
        1. binary search netPtIn
        2. if netScyOut is greater & approx minScyOut => answer found

        Psuedo code:
        binary search netPtIn:
            netAssetOut = calcTrade(netPtIn)
            if (netScyOut >= minScyOut):
                guessMax = netPtIn;
                if (netScyOut `greaterApprox` minScyOut) => answer found
            else:
                guessMin = netPtIn;
        */

        require(isValidApproxParams(approx), "invalid approx approx");

        VarsSwapPtForExactScy memory vars;
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);

        if (approx.guessMax == type(uint256).max) approx.guessMax = calcMaxPtIn(comp.totalAsset);

        vars.minAssetOut = index.scyToAsset(minScyOut);

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            vars.netPtInGuess = getCurrentGuess(iter, approx);

            (vars.isSlopeNonNeg, vars.largestGoodSlope) = updateSlope(
                comp,
                market.totalPt,
                vars.netPtInGuess,
                vars.largestGoodSlope
            );
            if (!vars.isSlopeNonNeg) {
                approx.guessMax = vars.netPtInGuess;
                continue;
            }

            (vars.assetToAccount, ) = market.calcTrade(comp, vars.netPtInGuess.neg());
            vars.netAssetOut = vars.assetToAccount.Uint();

            if (vars.netAssetOut >= vars.minAssetOut) {
                approx.guessMax = vars.netPtInGuess;
                bool isAnswerAccepted = Math.isAGreaterApproxB(
                    vars.netAssetOut,
                    vars.minAssetOut,
                    approx.eps
                );
                if (isAnswerAccepted)
                    return (vars.netPtInGuess, index.assetToScy(vars.netAssetOut));
            } else {
                approx.guessMin = vars.netPtInGuess;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    struct VarsSwapExactScyForYt {
        uint256 ptInGuess;
        int256 assetToAccount;
        uint256 netAssetOut;
        uint256 amountAssetNeedMore;
        uint256 largestGoodSlope;
        bool isSlopeNonNeg;
        uint256 maxAssetIn;
    }

    /// `guessMin` & `guessMax` is to guess the `netPtIn` == `netYtOut`
    function approxSwapExactScyForYt(
        MarketState memory market,
        SCYIndex index,
        uint256 maxScyIn,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        pure
        returns (
            uint256, /*netYtOut*/
            uint256 /*netScyIn*/
        )
    {
        /*
        the algorithm is essentially to:
        1. Binary search netPtIn (therefore netScyOut)
        2. flashswap some netScyOut (now we owe netPtIn)
        3. Use netScyOut + additional SCY from user => convert to PT + YT
        4. Pay back PT & give user YT.
        5. If the PT loan can be successfully & amount of additional SCY is smallerApprox maxScyIn
        => answer found

        Psuedo code:
        maxAssetIn = maxScyIn -> asset
        binary search netPtIn:
            netAssetOut = calcTrade(netPtIn)
            totalAssetNeedMoreToConvertPt = netPtIn - netAssetOut
            if (totalAssetNeedMoreToConvertPt <= maxAssetIn):
                guessMin = netPtIn;
                if (totalAssetNeedMoreToConvertPt `smallerApprox` maxAssetIn) => answer found
            else:
                guessMax = netPtOut;
        */

        require(isValidApproxParams(approx), "invalid approx approx");

        VarsSwapExactScyForYt memory vars;
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);

        if (approx.guessMax == type(uint256).max) approx.guessMax = calcMaxPtIn(comp.totalAsset);

        vars.maxAssetIn = index.scyToAsset(maxScyIn);

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            // ytOutGuess = ptInGuess
            vars.ptInGuess = getCurrentGuess(iter, approx);

            (vars.isSlopeNonNeg, vars.largestGoodSlope) = updateSlope(
                comp,
                market.totalPt,
                vars.ptInGuess,
                vars.largestGoodSlope
            );
            if (!vars.isSlopeNonNeg) {
                approx.guessMax = vars.ptInGuess - 1;
                continue;
            }

            (vars.assetToAccount, ) = market.calcTrade(comp, vars.ptInGuess.neg());
            vars.netAssetOut = vars.assetToAccount.Uint();
            vars.amountAssetNeedMore = vars.ptInGuess - vars.netAssetOut;

            if (vars.amountAssetNeedMore <= vars.maxAssetIn) {
                approx.guessMin = vars.ptInGuess;
                bool isAnswerAccepted = Math.isASmallerApproxB(
                    vars.amountAssetNeedMore,
                    vars.maxAssetIn,
                    approx.eps
                );
                if (isAnswerAccepted)
                    return (vars.ptInGuess, index.assetToScy(vars.amountAssetNeedMore));
            } else {
                approx.guessMax = vars.ptInGuess - 1;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    function approxSwapExactScyForPt(
        MarketState memory market,
        SCYIndex index,
        uint256 maxScyIn,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        pure
        returns (
            uint256, /*netPtOut*/
            uint256 /*netScyIn*/
        )
    {
        /*
        the algorithm is essentially to:
        1. binary search netPtOut
        2. if netScyIn smaller & approx maxScyIn => answer found

        Psuedo code:
        maxAssetIn = maxScyIn -> asset
        binary search netPtOut:
            netAssetIn = calcTrade(netPtOut)
            if (netAssetIn <= maxAssetIn):
                guessMin = netPtOut
                if (netAssetIn `smallerApprox` maxAssetIn) => answer found
            else:
                guessMax = netPtOut;
        */

        require(isValidApproxParams(approx), "invalid approx approx");

        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = calcMaxPtOut(market.totalPt, comp);
        }

        uint256 maxAssetIn = index.scyToAsset(maxScyIn);

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            uint256 ptOutGuess = getCurrentGuess(iter, approx);
            (int256 assetToAccount, ) = market.calcTrade(comp, ptOutGuess.Int());
            uint256 netAssetIn = assetToAccount.abs();

            if (netAssetIn <= maxAssetIn) {
                approx.guessMin = ptOutGuess;
                bool isAnswerAccepted = Math.isASmallerApproxB(netAssetIn, maxAssetIn, approx.eps);
                if (isAnswerAccepted) return (ptOutGuess, index.assetToScy(netAssetIn));
            } else {
                approx.guessMax = ptOutGuess;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    function approxSwapYtForExactScy(
        MarketState memory market,
        SCYIndex index,
        uint256 minScyOut,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        pure
        returns (
            uint256, /*netYtIn*/
            uint256 /*netScyOut*/
        )
    {
        /*
        the algorithm is essentially to:
        1. Binary search netPtOut (therefore netScyIn) (netYtIn == netPtOut)
        2. flashswap netPtOut (now we owe netScyIn)
        3. Pair netPtOut with the corresponding amount of Yt => redeem Scy
        4. Pay back Scy & the exceed amount of Scy (netScyOut) is transferred out to user
        5. If netScyOut is greater approx minScyOut => answer found

        Psuedo code:
        minAssetOut = minScyOut -> asset
        binary search netPtOut:
            netAssetIn = calcTrade(netPtOut)
            netAssetFromPtYt = netPtOut
            netAssetOut = netAssetFromPtYt - netAssetIn
            if (netAssetOut >= minAssetOut):
                guessMax = netPtOut
                if (netAssetOut `greaterApprox` minAssetOut) => answer found
            else:
                guessMin = netPtOut;
        */

        require(isValidApproxParams(approx), "invalid approx approx");

        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = calcMaxPtOut(market.totalPt, comp);
        }

        uint256 minAssetOut = index.scyToAsset(minScyOut);

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            // ytInGuess = ptOutGuess
            uint256 ptOutGuess = getCurrentGuess(iter, approx);

            (int256 assetToAccount, ) = market.calcTrade(comp, ptOutGuess.Int());
            uint256 netAssetOwed = assetToAccount.abs();

            // since ptOutGuess is between guessMin & guessMax, it's guaranteed that
            // there are enough Yt to pair with ptOut

            uint256 netAssetOut = ptOutGuess - netAssetOwed;

            if (netAssetOut >= minAssetOut) {
                approx.guessMax = ptOutGuess;
                if (Math.isAGreaterApproxB(netAssetOut, minAssetOut, approx.eps)) {
                    return (ptOutGuess, index.assetToScy(netAssetOut));
                }
            } else {
                approx.guessMin = ptOutGuess + 1;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    function updateSlope(
        MarketPreCompute memory comp,
        int256 totalPt,
        uint256 ptInGuess,
        uint256 largestGoodSlope
    ) internal pure returns (bool isSlopeNonNeg, uint256 newLargestGoodSlop) {
        if (ptInGuess <= largestGoodSlope) {
            return (true, largestGoodSlope);
        }
        // it's not guaranteed that the current slop is good
        // we therefore have to recalculate the slope
        int256 slope = slopeFactor(totalPt, ptInGuess.neg(), comp);
        if (slope >= 0) return (true, ptInGuess);
        else return (false, largestGoodSlope);
    }

    // ptToMarket < totalAsset && totalPt
    function slopeFactor(
        int256 totalPt,
        int256 ptToAccount,
        MarketPreCompute memory comp
    ) internal pure returns (int256) {
        int256 ptToMarket = -ptToAccount;
        int256 diffAssetPtToMarket = comp.totalAsset - ptToMarket;
        int256 sumPt = ptToMarket + totalPt;

        require(diffAssetPtToMarket > 0 && sumPt > 0, "invalid ptToMarket");

        int256 part1 = (ptToMarket * (totalPt + comp.totalAsset)).divDown(
            sumPt * diffAssetPtToMarket
        );

        int256 part2 = sumPt.divDown(diffAssetPtToMarket).ln();
        int256 part3 = Math.IONE.divDown(comp.rateScalar);

        return comp.rateAnchor - (part1 - part2).mulDown(part3);
    }

    function calcMaxPtOut(int256 totalPt, MarketPreCompute memory comp)
        internal
        pure
        returns (uint256)
    {
        int256 logitP = (Math.IONE.mulDown(comp.feeRate) - comp.rateAnchor)
            .mulDown(comp.rateScalar)
            .exp();
        int256 proportion = logitP.divDown(logitP + Math.IONE);
        int256 numerator = proportion.mulDown(totalPt + comp.totalAsset);
        int256 maxPtOut = totalPt - numerator;
        // only get 99.9% of the theoretical max to accommodate some precision issues
        return (maxPtOut.Uint() * 999) / 1000;
    }

    function calcMaxPtIn(int256 totalAsset) internal pure returns (uint256) {
        return totalAsset.Uint() - 1;
    }

    function isValidApproxParams(ApproxParams memory approx) internal pure returns (bool) {
        return (approx.guessMin <= approx.guessMax && approx.eps <= Math.ONE);
    }

    function getCurrentGuess(uint256 iteration, ApproxParams memory approx)
        internal
        pure
        returns (uint256)
    {
        if (iteration == 0 && approx.guessOffchain != 0) return approx.guessOffchain;
        else {
            if (approx.guessMin > approx.guessMax) return approx.guessMax;
            return (approx.guessMin + approx.guessMax) / 2;
        }
    }
}
