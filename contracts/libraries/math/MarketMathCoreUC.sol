// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./MathUC.sol";
import "./LogExpMath.sol";
import "../helpers/PYIndexUC.sol";
import "../helpers/MiniHelpers.sol";

// solhint-disable ordering
library MarketMathCoreUC {
    using MathUC for uint256;
    using MathUC for int256;
    using LogExpMath for int256;
    using PYIndexLibUC for PYIndex;

    int256 internal constant MINIMUM_LIQUIDITY = 10**3;
    int256 internal constant PERCENTAGE_DECIMALS = 100;
    uint256 internal constant DAY = 86400;
    uint256 internal constant IMPLIED_RATE_TIME = 365 * DAY;

    int256 internal constant MAX_MARKET_PROPORTION = (1e18 * 96) / 100;

    /*///////////////////////////////////////////////////////////////
                UINT FUNCTIONS TO PROXY TO CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addLiquidity(
        MarketState memory market,
        uint256 scyDesired,
        uint256 ptDesired,
        uint256 blockTime
    )
        internal
        pure
        returns (
            uint256 lpToReserve,
            uint256 lpToAccount,
            uint256 scyUsed,
            uint256 ptUsed
        )
    {
        unchecked {
            (
                int256 _lpToReserve,
                int256 _lpToAccount,
                int256 _scyUsed,
                int256 _otUsed
            ) = addLiquidityCore(market, scyDesired.Int(), ptDesired.Int(), blockTime);

            lpToReserve = _lpToReserve.Uint();
            lpToAccount = _lpToAccount.Uint();
            scyUsed = _scyUsed.Uint();
            ptUsed = _otUsed.Uint();
        }
    }

    function removeLiquidity(MarketState memory market, uint256 lpToRemove)
        internal
        pure
        returns (uint256 scyToAccount, uint256 netPtToAccount)
    {
        unchecked {
            (int256 _scyToAccount, int256 _ptToAccount) = removeLiquidityCore(
                market,
                lpToRemove.Int()
            );

            scyToAccount = _scyToAccount.Uint();
            netPtToAccount = _ptToAccount.Uint();
        }
    }

    function swapExactPtForScy(
        MarketState memory market,
        PYIndex index,
        uint256 exactPtToMarket,
        uint256 blockTime
    ) internal pure returns (uint256 netScyToAccount, uint256 netScyToReserve) {
        unchecked {
            (int256 _netScyToAccount, int256 _netScyToReserve) = executeTradeCore(
                market,
                index,
                exactPtToMarket.neg(),
                blockTime
            );

            netScyToAccount = _netScyToAccount.Uint();
            netScyToReserve = _netScyToReserve.Uint();
        }
    }

    function swapScyForExactPt(
        MarketState memory market,
        PYIndex index,
        uint256 exactPtToAccount,
        uint256 blockTime
    ) internal pure returns (uint256 netScyToMarket, uint256 netScyToReserve) {
        unchecked {
            (int256 _netScyToAccount, int256 _netScyToReserve) = executeTradeCore(
                market,
                index,
                exactPtToAccount.Int(),
                blockTime
            );

            netScyToMarket = _netScyToAccount.neg().Uint();
            netScyToReserve = _netScyToReserve.Uint();
        }
    }

    /*///////////////////////////////////////////////////////////////
                    CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addLiquidityCore(
        MarketState memory market,
        int256 scyDesired,
        int256 ptDesired,
        uint256 blockTime
    )
        internal
        pure
        returns (
            int256 lpToReserve,
            int256 lpToAccount,
            int256 scyUsed,
            int256 ptUsed
        )
    {
        unchecked {
            /// ------------------------------------------------------------
            /// CHECKS
            /// ------------------------------------------------------------
            require(scyDesired > 0 && ptDesired > 0, "ZERO_AMOUNTS");
            require(!MiniHelpers.isExpired(market.expiry, blockTime), "market expired");

            /// ------------------------------------------------------------
            /// MATH
            /// ------------------------------------------------------------
            if (market.totalLp == 0) {
                lpToAccount =
                    MathUC.sqrt((scyDesired * ptDesired).Uint()).Int() -
                    MINIMUM_LIQUIDITY;
                lpToReserve = MINIMUM_LIQUIDITY;
                scyUsed = scyDesired;
                ptUsed = ptDesired;
            } else {
                int256 netLpByPt = (ptDesired * market.totalLp) / market.totalPt;
                int256 netLpByScy = (scyDesired * market.totalLp) / market.totalScy;
                if (netLpByPt < netLpByScy) {
                    lpToAccount = netLpByPt;
                    ptUsed = ptDesired;
                    scyUsed = (market.totalScy * lpToAccount) / market.totalLp;
                } else {
                    lpToAccount = netLpByScy;
                    scyUsed = scyDesired;
                    ptUsed = (market.totalPt * lpToAccount) / market.totalLp;
                }
            }

            require(lpToAccount > 0, "INSUFFICIENT_LIQUIDITY_MINTED");

            /// ------------------------------------------------------------
            /// WRITE
            /// ------------------------------------------------------------
            market.totalScy += scyUsed;
            market.totalPt += ptUsed;
            market.totalLp += lpToAccount + lpToReserve;
        }
    }

    function removeLiquidityCore(MarketState memory market, int256 lpToRemove)
        internal
        pure
        returns (int256 netScyToAccount, int256 netPtToAccount)
    {
        unchecked {
            /// ------------------------------------------------------------
            /// CHECKS
            /// ------------------------------------------------------------
            require(lpToRemove > 0, "invalid lp amount");

            /// ------------------------------------------------------------
            /// MATH
            /// ------------------------------------------------------------
            netScyToAccount = (lpToRemove * market.totalScy) / market.totalLp;
            netPtToAccount = (lpToRemove * market.totalPt) / market.totalLp;

            require(netScyToAccount > 0 || netPtToAccount > 0, "zero amounts out");
            /// ------------------------------------------------------------
            /// WRITE
            /// ------------------------------------------------------------
            market.totalLp = market.totalLp.subNoNeg(lpToRemove);
            market.totalPt = market.totalPt.subNoNeg(netPtToAccount);
            market.totalScy = market.totalScy.subNoNeg(netScyToAccount);
        }
    }

    function executeTradeCore(
        MarketState memory market,
        PYIndex index,
        int256 netPtToAccount,
        uint256 blockTime
    ) internal pure returns (int256 netScyToAccount, int256 netScyToReserve) {
        unchecked {
            /// ------------------------------------------------------------
            /// CHECKS
            /// ------------------------------------------------------------
            require(!MiniHelpers.isExpired(market.expiry, blockTime), "market expired");
            require(market.totalPt > netPtToAccount, "insufficient liquidity");

            /// ------------------------------------------------------------
            /// MATH
            /// ------------------------------------------------------------
            MarketPreCompute memory comp = getMarketPreCompute(market, index, blockTime);

            (int256 netAssetToAccount, int256 netAssetToReserve) = calcTrade(
                market,
                comp,
                netPtToAccount
            );

            netScyToAccount = netAssetToAccount < 0
                ? index.assetToScyUp(netAssetToAccount)
                : index.assetToScy(netAssetToAccount);
            netScyToReserve = index.assetToScy(netAssetToReserve);

            /// ------------------------------------------------------------
            /// WRITE
            /// ------------------------------------------------------------
            _setNewMarketStateTrade(
                market,
                comp,
                index,
                netPtToAccount,
                netScyToAccount,
                netScyToReserve,
                blockTime
            );
        }
    }

    function getMarketPreCompute(
        MarketState memory market,
        PYIndex index,
        uint256 blockTime
    ) internal pure returns (MarketPreCompute memory res) {
        unchecked {
            require(!MiniHelpers.isExpired(market.expiry, blockTime), "market expired");

            uint256 timeToExpiry = market.expiry - blockTime;

            res.rateScalar = _getRateScalar(market, timeToExpiry);
            res.totalAsset = index.scyToAsset(market.totalScy);

            require(market.totalPt != 0 && res.totalAsset != 0, "invalid market state");

            res.rateAnchor = _getRateAnchor(
                market.totalPt,
                market.lastLnImpliedRate,
                res.totalAsset,
                res.rateScalar,
                timeToExpiry
            );
            res.feeRate = _getExchangeRateFromImpliedRate(market.lnFeeRateRoot, timeToExpiry);
        }
    }

    function calcTrade(
        MarketState memory market,
        MarketPreCompute memory comp,
        int256 netPtToAccount
    ) internal pure returns (int256 netAssetToAccount, int256 netAssetToReserve) {
        unchecked {
            int256 preFeeExchangeRate = _getExchangeRate(
                market.totalPt,
                comp.totalAsset,
                comp.rateScalar,
                comp.rateAnchor,
                netPtToAccount
            );

            int256 preFeeAssetToAccount = netPtToAccount.divDown(preFeeExchangeRate).neg();
            int256 fee = comp.feeRate;

            if (netPtToAccount > 0) {
                int256 postFeeExchangeRate = preFeeExchangeRate.divDown(fee);
                require(postFeeExchangeRate >= MathUC.IONE, "exchange rate below 1");
                fee = preFeeAssetToAccount.mulDown(MathUC.IONE - fee);
            } else {
                fee = ((preFeeAssetToAccount * (MathUC.IONE - fee)) / fee).neg();
            }

            netAssetToReserve = (fee * market.reserveFeePercent.Int()) / PERCENTAGE_DECIMALS;
            netAssetToAccount = preFeeAssetToAccount - fee;
        }
    }

    function _setNewMarketStateTrade(
        MarketState memory market,
        MarketPreCompute memory comp,
        PYIndex index,
        int256 netPtToAccount,
        int256 netScyToAccount,
        int256 netScyToReserve,
        uint256 blockTime
    ) internal pure {
        unchecked {
            uint256 timeToExpiry = market.expiry - blockTime;

            market.totalPt = market.totalPt.subNoNeg(netPtToAccount);
            market.totalScy = market.totalScy.subNoNeg(netScyToAccount + netScyToReserve);

            market.lastLnImpliedRate = _getLnImpliedRate(
                market.totalPt,
                index.scyToAsset(market.totalScy),
                comp.rateScalar,
                comp.rateAnchor,
                timeToExpiry
            );
            require(market.lastLnImpliedRate != 0, "zero lnImpliedRate");
        }
    }

    function _getRateAnchor(
        int256 totalPt,
        uint256 lastLnImpliedRate,
        int256 totalAsset,
        int256 rateScalar,
        uint256 timeToExpiry
    ) internal pure returns (int256 rateAnchor) {
        unchecked {
            int256 newExchangeRate = _getExchangeRateFromImpliedRate(
                lastLnImpliedRate,
                timeToExpiry
            );

            require(newExchangeRate >= MathUC.IONE, "exchange rate below 1");

            {
                int256 proportion = totalPt.divDown(totalPt + totalAsset);

                int256 lnProportion = _logProportion(proportion);

                rateAnchor = newExchangeRate - lnProportion.divDown(rateScalar);
            }
        }
    }

    /// @notice Calculates the current market implied rate.
    /// @return lnImpliedRate the implied rate
    function _getLnImpliedRate(
        int256 totalPt,
        int256 totalAsset,
        int256 rateScalar,
        int256 rateAnchor,
        uint256 timeToExpiry
    ) internal pure returns (uint256 lnImpliedRate) {
        unchecked {
            // This will check for exchange rates < MathUC.IONE
            int256 exchangeRate = _getExchangeRate(totalPt, totalAsset, rateScalar, rateAnchor, 0);

            // exchangeRate >= 1 so its ln >= 0
            uint256 lnRate = exchangeRate.ln().Uint();

            lnImpliedRate = (lnRate * IMPLIED_RATE_TIME) / timeToExpiry;
        }
    }

    /// @notice Converts an implied rate to an exchange rate given a time to expiry. The
    /// formula is E = e^rt
    function _getExchangeRateFromImpliedRate(uint256 lnImpliedRate, uint256 timeToExpiry)
        internal
        pure
        returns (int256 exchangeRate)
    {
        unchecked {
            uint256 rt = (lnImpliedRate * timeToExpiry) / IMPLIED_RATE_TIME;

            exchangeRate = LogExpMath.exp(rt.Int());
        }
    }

    function _getExchangeRate(
        int256 totalPt,
        int256 totalAsset,
        int256 rateScalar,
        int256 rateAnchor,
        int256 netPtToAccount
    ) internal pure returns (int256 exchangeRate) {
        unchecked {
            int256 numerator = totalPt.subNoNeg(netPtToAccount);

            int256 proportion = (numerator.divDown(totalPt + totalAsset));

            require(proportion <= MAX_MARKET_PROPORTION, "max proportion exceeded");

            int256 lnProportion = _logProportion(proportion);

            exchangeRate = lnProportion.divDown(rateScalar) + rateAnchor;

            require(exchangeRate >= MathUC.IONE, "exchange rate below 1");
        }
    }

    function _logProportion(int256 proportion) internal pure returns (int256 res) {
        unchecked {
            require(proportion != MathUC.IONE, "proportion must not be one");

            int256 logitP = proportion.divDown(MathUC.IONE - proportion);

            res = logitP.ln();
        }
    }

    function _getRateScalar(MarketState memory market, uint256 timeToExpiry)
        internal
        pure
        returns (int256 rateScalar)
    {
        unchecked {
            rateScalar = (market.scalarRoot * IMPLIED_RATE_TIME.Int()) / timeToExpiry.Int();
            require(rateScalar > 0, "rateScalar underflow");
        }
    }

    function setInitialLnImpliedRate(
        MarketState memory market,
        PYIndex index,
        int256 initialAnchor,
        uint256 blockTime
    ) internal pure {
        unchecked {
            /// ------------------------------------------------------------
            /// CHECKS
            /// ------------------------------------------------------------
            require(blockTime < market.expiry, "market expired");

            /// ------------------------------------------------------------
            /// MATH
            /// ------------------------------------------------------------
            int256 totalAsset = index.scyToAsset(market.totalScy);
            uint256 timeToExpiry = market.expiry - blockTime;
            int256 rateScalar = _getRateScalar(market, timeToExpiry);

            /// ------------------------------------------------------------
            /// WRITE
            /// ------------------------------------------------------------
            market.lastLnImpliedRate = _getLnImpliedRate(
                market.totalPt,
                totalAsset,
                rateScalar,
                initialAnchor,
                timeToExpiry
            );
        }
    }
}
