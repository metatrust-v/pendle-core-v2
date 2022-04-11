// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../SuperComposableYield/ISuperComposableYield.sol";
import "../../interfaces/IPMarket.sol";
import "./FixedPoint.sol";
import "./LogExpMath.sol";
import "../../SuperComposableYield/implementations/SCYUtils.sol";

// if this is changed, change deepCloneMarket as well
struct MarketParameters {
    int256 totalOt;
    int256 totalScy;
    int256 totalLp;
    uint256 scyRate;
    uint256 oracleRate;
    /// immutable variables ///
    int256 scalarRoot;
    uint256 feeRateRoot;
    int256 anchorRoot;
    uint256 rateOracleTimeWindow;
    uint256 expiry;
    int256 reserveFeePercent; // base 100
    /// last trade data ///
    uint256 lastImpliedRate;
    uint256 lastTradeTime;
}

// TODO: Is 112 enough for rate?
struct MarketStorage {
    int128 totalOt;
    int128 totalScy;
    uint112 lastImpliedRate;
    uint112 oracleRate;
    uint32 lastTradeTime;
}

// solhint-disable reason-string, ordering
library MarketMathLib {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using LogExpMath for int256;
    struct NetTo {
        int256 toAccount;
        int256 toMarket;
        int256 toReserve;
    }

    int256 internal constant MINIMUM_LIQUIDITY = 10**3;
    int256 internal constant PERCENTAGE_DECIMALS = 100;
    uint256 internal constant DAY = 86400;
    uint256 internal constant IMPLIED_RATE_TIME = 360 * DAY;

    // TODO: make sure 1e18 == FixedPoint.ONE
    int256 internal constant MAX_MARKET_PROPORTION = (1e18 * 96) / 100;

    function addLiquidity(
        MarketParameters memory market,
        uint256 _scyDesired,
        uint256 _otDesired
    )
        internal
        pure
        returns (
            uint256 _lpToReserve,
            uint256 _lpToAccount,
            uint256 _scyUsed,
            uint256 _otUsed
        )
    {
        int256 scyDesired = _scyDesired.Int();
        int256 otDesired = _otDesired.Int();
        int256 lpToReserve;
        int256 lpToAccount;
        int256 scyUsed;
        int256 otUsed;

        require(scyDesired > 0 && otDesired > 0, "ZERO_AMOUNTS");

        if (market.totalLp == 0) {
            lpToAccount = SCYUtils.scyToAsset(market.scyRate, scyDesired).subNoNeg(
                MINIMUM_LIQUIDITY
            );
            lpToReserve = MINIMUM_LIQUIDITY;
            scyUsed = scyDesired;
            otUsed = otDesired;
        } else {
            lpToAccount = FixedPoint.min(
                (otDesired * market.totalLp) / market.totalOt,
                (scyDesired * market.totalLp) / market.totalScy
            );
            scyUsed = (market.totalScy * lpToAccount) / market.totalLp;
            otUsed = (market.totalOt * lpToAccount) / market.totalLp;
        }

        market.totalScy += scyUsed;
        market.totalOt += otUsed;
        market.totalLp += lpToAccount + lpToReserve;

        require(lpToAccount > 0, "INSUFFICIENT_LIQUIDITY_MINTED");

        _lpToReserve = lpToReserve.Uint();
        _lpToAccount = lpToAccount.Uint();
        _scyUsed = scyUsed.Uint();
        _otUsed = otUsed.Uint();
    }

    function removeLiquidity(MarketParameters memory market, uint256 _lpToRemove)
        internal
        pure
        returns (uint256 _scyToAccount, uint256 _otToAccount)
    {
        int256 lpToRemove = _lpToRemove.Int();
        int256 scyToAccount;
        int256 otToAccount;

        require(lpToRemove > 0, "invalid lp amount");

        scyToAccount = (lpToRemove * market.totalScy) / market.totalLp;
        otToAccount = (lpToRemove * market.totalOt) / market.totalLp;

        market.totalLp = market.totalLp.subNoNeg(lpToRemove);
        require(market.totalLp > MINIMUM_LIQUIDITY, "minimum liquidity reached");
        market.totalOt = market.totalOt.subNoNeg(otToAccount);
        market.totalScy = market.totalScy.subNoNeg(scyToAccount);

        _scyToAccount = scyToAccount.Uint();
        _otToAccount = otToAccount.Uint();
    }

    function calcExactOtForSCY(
        MarketParameters memory market,
        uint256 exactOtToMarket,
        uint256 blockTime
    ) internal pure returns (uint256 netSCYToAccount, uint256 netSCYToReserve) {
        (int256 _netSCYToAccount, int256 _netSCYToReserve) = calcTrade(
            market,
            exactOtToMarket.neg(),
            blockTime
        );
        netSCYToAccount = _netSCYToAccount.Uint();
        netSCYToReserve = _netSCYToReserve.Uint();
    }

    function calcSCYForExactOt(
        MarketParameters memory market,
        uint256 exactOtToAccount,
        uint256 blockTime
    ) internal pure returns (uint256 netSCYToMarket, uint256 netSCYToReserve) {
        (int256 _netSCYToAccount, int256 _netSCYToReserve) = calcTrade(
            market,
            exactOtToAccount.Int(),
            blockTime
        );
        netSCYToMarket = _netSCYToAccount.neg().Uint();
        netSCYToReserve = _netSCYToReserve.Uint();
    }

    /// @notice Calculates the asset amount the results from trading otToAccount with the market. A positive
    /// otToAccount is equivalent of swapping OT into the market, a negative is taking OT out.
    /// Updates the market state in memory.
    /// @param market the current market state
    /// @param otToAccount the OT amount that will be deposited into the user's portfolio. The net change
    /// to the market is in the opposite direction.
    /// @return netSCYToAccount netSCYToReserve
    function calcTrade(
        MarketParameters memory market,
        int256 otToAccount,
        uint256 blockTime
    ) internal pure returns (int256 netSCYToAccount, int256 netSCYToReserve) {
        require(blockTime < market.expiry, "MARKET_EXPIRED");
        uint256 timeToExpiry = market.expiry - blockTime;

        // We return false if there is not enough Ot to support this trade.
        // if otToAccount > 0 and totalOt - otToAccount <= 0 then the trade will fail
        // if otToAccount < 0 and totalOt > 0 then this will always pass
        require(market.totalOt > otToAccount, "insufficient liquidity");

        // Calculates initial rate factors for the trade
        (int256 rateScalar, int256 totalAsset, int256 rateAnchor) = getExchangeRateFactors(
            market,
            timeToExpiry
        );

        // Calculates the exchange rate from Asset to OT before any liquidity fees
        // are applied
        int256 preFeeExchangeRate;
        {
            preFeeExchangeRate = getExchangeRate(
                market.totalOt,
                totalAsset,
                rateScalar,
                rateAnchor,
                otToAccount
            );
        }

        NetTo memory netAsset;
        // Given the exchange rate, returns the netAsset amounts to apply to each of the
        // three relevant balances.
        (
            netAsset.toAccount,
            netAsset.toMarket,
            netAsset.toReserve
        ) = _getNetAssetAmountsToAddresses(
            market.feeRateRoot,
            preFeeExchangeRate,
            otToAccount,
            timeToExpiry,
            market.reserveFeePercent
        );

        //////////////////////////////////
        /// Update params in the market///
        //////////////////////////////////
        {
            // Set the new implied interest rate after the trade has taken effect, this
            // will be used to calculate the next trader's interest rate.
            market.totalOt = market.totalOt.subNoNeg(otToAccount);
            market.lastImpliedRate = getImpliedRate(
                market.totalOt,
                totalAsset + netAsset.toMarket,
                rateScalar,
                rateAnchor,
                timeToExpiry
            );

            // It's technically possible that the implied rate is actually exactly zero (or
            // more accurately the natural log rounds down to zero) but we will still fail
            // in this case. If this does happen we may assume that markets are not initialized.
            require(market.lastImpliedRate != 0);
        }

        (netSCYToAccount, netSCYToReserve) = _setNewMarketState(
            market,
            netAsset.toAccount,
            netAsset.toMarket,
            netAsset.toReserve,
            blockTime
        );
    }

    /// @notice Returns factors for calculating exchange rates
    /// @return rateScalar a value in rate precision that defines the slope of the line
    /// @return totalAsset the converted SCY to Asset for calculatin the exchange rates for the trade
    /// @return rateAnchor an offset from the x axis to maintain interest rate continuity over time
    function getExchangeRateFactors(MarketParameters memory market, uint256 timeToExpiry)
        internal
        pure
        returns (
            int256 rateScalar,
            int256 totalAsset,
            int256 rateAnchor
        )
    {
        rateScalar = getRateScalar(market, timeToExpiry);
        totalAsset = SCYUtils.scyToAsset(market.scyRate, market.totalScy);

        require(market.totalOt != 0 && totalAsset != 0);

        // Get the rateAnchor given the market state, this will establish the baseline for where
        // the exchange rate is set.
        {
            rateAnchor = _getRateAnchor(
                market.totalOt,
                market.lastImpliedRate,
                totalAsset,
                rateScalar,
                timeToExpiry
            );
        }
    }

    /// @dev Returns net Asset amounts to the account, the market and the reserve. netAssetToReserve
    /// is actually the fee portion of the trade
    /// @return netAssetToAccount this is a positive or negative amount of Asset change to the account
    /// @return netAssetToMarket this is a positive or negative amount of Asset change in the market
    /// @return netAssetToReserve this is always a positive amount of Asset accrued to the reserve
    function _getNetAssetAmountsToAddresses(
        uint256 feeRateRoot,
        int256 preFeeExchangeRate,
        int256 otToAccount,
        uint256 timeToExpiry,
        int256 reserveFeePercent
    )
        private
        pure
        returns (
            int256 netAssetToAccount,
            int256 netAssetToMarket,
            int256 netAssetToReserve
        )
    {
        // Fees are specified in basis points which is an rate precision denomination. We convert this to
        // an exchange rate denomination for the given time to expiry. (i.e. get e^(fee * t) and multiply
        // or divide depending on the side of the trade).
        // tradeExchangeRate = exp((tradeInterestRateNoFee +/- fee) * timeToExpiry)
        // tradeExchangeRate = tradeExchangeRateNoFee (* or /) exp(fee * timeToExpiry)
        // Asset = OT / exchangeRate, exchangeRate > 1
        int256 preFeeAssetToAccount = otToAccount.divDown(preFeeExchangeRate).neg();
        int256 fee = getExchangeRateFromImpliedRate(feeRateRoot, timeToExpiry);

        if (otToAccount > 0) {
            // swapping SCY for OT

            // Dividing reduces exchange rate, swapping SCY to OT means account should receive less OT
            int256 postFeeExchangeRate = preFeeExchangeRate.divDown(fee);
            // It's possible that the fee pushes exchange rates into negative territory. This is not possible
            // when swapping OT to SCY. If this happens then the trade has failed.
            require(postFeeExchangeRate >= FixedPoint.ONE_INT, "exchange rate below 1");

            // assetToAccount = -(otToAccount / exchangeRate)
            // postFeeExchangeRate = preFeeExchangeRate / feeExchangeRate
            // preFeeAssetToAccount = -(otToAccount / preFeeExchangeRate)
            // postFeeAssetToAccount = -(otToAccount / postFeeExchangeRate)
            // netFee = preFeeAssetToAccount - postFeeAssetToAccount
            // netFee = (otToAccount / postFeeExchangeRate) - (otToAccount / preFeeExchangeRate)
            // netFee = ((otToAccount * feeExchangeRate) / preFeeExchangeRate) - (otToAccount / preFeeExchangeRate)
            // netFee = (otToAccount / preFeeExchangeRate) * (feeExchangeRate - 1)
            // netFee = -(preFeeAssetToAccount) * (feeExchangeRate - 1)
            // netFee = preFeeAssetToAccount * (1 - feeExchangeRate)
            // RATE_PRECISION - fee will be negative here, preFeeAssetToAccount < 0, fee > 0
            fee = preFeeAssetToAccount.mulDown(FixedPoint.ONE_INT - fee);
        } else {
            // swapping OT for SCY

            // assetToAccount = -(otToAccount / exchangeRate)
            // postFeeExchangeRate = preFeeExchangeRate * feeExchangeRate

            // netFee = preFeeAssetToAccount - postFeeAssetToAccount
            // netFee = (otToAccount / postFeeExchangeRate) - (otToAccount / preFeeExchangeRate)
            // netFee = ((otToAccount / (feeExchangeRate * preFeeExchangeRate)) - (otToAccount / preFeeExchangeRate)
            // netFee = (otToAccount / preFeeExchangeRate) * (1 / feeExchangeRate - 1)
            // netFee = preFeeAssetToAccount * ((1 - feeExchangeRate) / feeExchangeRate)
            // NOTE: preFeeAssetToAccount is negative in this branch so we negate it to ensure that fee is a positive number
            // preFee * (1 - fee) / fee will be negative, use neg() to flip to positive
            // RATE_PRECISION - fee will be negative
            fee = ((preFeeAssetToAccount * (FixedPoint.ONE_INT - fee)) / fee).neg();
        }

        netAssetToReserve = (fee * reserveFeePercent) / PERCENTAGE_DECIMALS;

        // postFeeAssetToAccount = preFeeAssetToAccount - fee
        netAssetToAccount = preFeeAssetToAccount - fee;
        netAssetToMarket = (preFeeAssetToAccount - fee + netAssetToReserve).neg();
    }

    /// @notice Sets the new market state
    /// @return netSCYToAccount the positive or negative change in asset scy to the account
    /// @return netSCYToReserve the positive amount of scy that accrues to the reserve
    function _setNewMarketState(
        MarketParameters memory market,
        int256 netAssetToAccount,
        int256 netAssetToMarket,
        int256 netAssetToReserve,
        uint256 blockTime
    ) private pure returns (int256 netSCYToAccount, int256 netSCYToReserve) {
        int256 netSCYToMarket = SCYUtils.assetToSCY(market.scyRate, netAssetToMarket);
        // Set storage checks that total asset scy is above zero
        market.totalScy = market.totalScy + netSCYToMarket;

        market.lastTradeTime = blockTime;
        netSCYToReserve = SCYUtils.assetToSCY(market.scyRate, netAssetToReserve);
        netSCYToAccount = SCYUtils.assetToSCY(market.scyRate, netAssetToAccount);
    }

    /// @notice Rate anchors update as the market gets closer to expiry. Rate anchors are not comparable
    /// across time or markets but implied rates are. The goal here is to ensure that the implied rate
    /// before and after the rate anchor update is the same. Therefore, the market will trade at the same implied
    /// rate that it last traded at. If these anchors do not update then it opens up the opportunity for arbitrage
    /// which will hurt the liquidity providers.
    ///
    /// The rate anchor will update as the market rolls down to expiry. The calculation is:
    /// newExchangeRate = e^(lastImpliedRate * timeToExpiry / Constants.IMPLIED_RATE_TIME)
    /// newAnchor = newExchangeRate - ln((proportion / (1 - proportion)) / rateScalar
    ///
    /// where:
    /// lastImpliedRate = ln(exchangeRate') * (Constants.IMPLIED_RATE_TIME / timeToExpiry')
    ///      (calculated when the last trade in the market was made)
    /// @return rateAnchor the new rateAnchor
    function _getRateAnchor(
        int256 totalOt,
        uint256 lastImpliedRate,
        int256 totalAsset,
        int256 rateScalar,
        uint256 timeToExpiry
    ) internal pure returns (int256 rateAnchor) {
        // This is the exchange rate at the new time to expiry
        int256 newExchangeRate = getExchangeRateFromImpliedRate(lastImpliedRate, timeToExpiry);

        require(newExchangeRate >= FixedPoint.ONE_INT, "exchange rate below 1");

        {
            // totalOt / (totalOt + totalAsset)
            int256 proportion = totalOt.divDown(totalOt + totalAsset);

            int256 lnProportion = _logProportion(proportion);

            // newExchangeRate - ln(proportion / (1 - proportion)) / rateScalar
            rateAnchor = newExchangeRate - lnProportion.divDown(rateScalar);
        }
    }

    /// @notice Calculates the current market implied rate.
    /// @return impliedRate the implied rate
    function getImpliedRate(
        int256 totalOt,
        int256 totalAsset,
        int256 rateScalar,
        int256 rateAnchor,
        uint256 timeToExpiry
    ) internal pure returns (uint256 impliedRate) {
        // This will check for exchange rates < FixedPoint.ONE_INT
        int256 exchangeRate = getExchangeRate(totalOt, totalAsset, rateScalar, rateAnchor, 0);

        // exchangeRate >= 1 so its ln >= 0
        uint256 lnRate = exchangeRate.ln().Uint();

        impliedRate = (lnRate * IMPLIED_RATE_TIME) / timeToExpiry;
    }

    /// @notice Converts an implied rate to an exchange rate given a time to expiry. The
    /// formula is E = e^rt
    function getExchangeRateFromImpliedRate(uint256 impliedRate, uint256 timeToExpiry)
        internal
        pure
        returns (int256 exchangeRate)
    {
        uint256 rt = (impliedRate * timeToExpiry) / IMPLIED_RATE_TIME;

        exchangeRate = LogExpMath.exp(rt.Int());
    }

    /// @notice Returns the exchange rate between OT and Asset for the given market
    /// Calculates the following exchange rate:
    ///     (1 / rateScalar) * ln(proportion / (1 - proportion)) + rateAnchor
    /// where:
    ///     proportion = totalOt / (totalOt + totalUnderlyingAsset)
    function getExchangeRate(
        int256 totalOt,
        int256 totalAsset,
        int256 rateScalar,
        int256 rateAnchor,
        int256 otToAccount
    ) internal pure returns (int256 exchangeRate) {
        int256 numerator = totalOt.subNoNeg(otToAccount);

        // This is the proportion scaled by FixedPoint.ONE_INT
        // (totalOt + otToMarket) / (totalOt + totalAsset)
        int256 proportion = (numerator.divDown(totalOt + totalAsset));

        // This limit is here to prevent the market from reaching extremely high interest rates via an
        // excessively large proportion (high amounts of OT relative to Asset).
        // Market proportion can only increase via swapping OT to SCY (OT is added to the market and SCY is
        // removed). Over time, the yield from SCY will slightly decrease the proportion (the
        // amount of Asset in the market must be monotonically increasing). Therefore it is not
        // possible for the proportion to go over max market proportion unless borrowing occurs.
        require(proportion <= MAX_MARKET_PROPORTION); // TODO: probably not applicable to Pendle

        int256 lnProportion = _logProportion(proportion);

        // lnProportion / rateScalar + rateAnchor
        exchangeRate = lnProportion.divDown(rateScalar) + rateAnchor;

        // Do not succeed if interest rates fall below 1
        require(exchangeRate >= FixedPoint.ONE_INT, "exchange rate below 1");
    }

    function _logProportion(int256 proportion) internal pure returns (int256 res) {
        // This will result in divide by zero, short circuit
        require(proportion != FixedPoint.ONE_INT);

        // Convert proportion to what is used inside the logit function (p / (1-p))
        int256 logitP = proportion.divDown(FixedPoint.ONE_INT - proportion);

        res = logitP.ln();
    }

    function getRateScalar(MarketParameters memory market, uint256 timeToExpiry)
        internal
        pure
        returns (int256 rateScalar)
    {
        rateScalar = (market.scalarRoot * IMPLIED_RATE_TIME.Int()) / timeToExpiry.Int();
        require(rateScalar > 0, "rateScalar underflow");
    }

    function setInitialImpliedRate(MarketParameters memory market, uint256 timeToExpiry)
        internal
        pure
    {
        int256 totalAsset = SCYUtils.scyToAsset(market.scyRate, market.totalScy);
        market.lastImpliedRate = getImpliedRate(
            market.totalOt,
            totalAsset,
            market.scalarRoot,
            market.anchorRoot,
            timeToExpiry
        );
    }

    function updateNewRateOracle(MarketParameters memory market, uint256 blockTime)
        internal
        pure
        returns (uint256)
    {
        // require(rateOracleTimeWindow > 0); // dev: update rate oracle, time window zero

        // This can occur when using a view function get to a market state in the past
        if (market.lastTradeTime > blockTime) {
            market.oracleRate = market.lastImpliedRate;
            return market.oracleRate;
        }

        uint256 timeDiff = blockTime - market.lastTradeTime;
        if (timeDiff > market.rateOracleTimeWindow) {
            // If past the time window just return the market.lastImpliedRate
            market.oracleRate = market.lastImpliedRate;
            return market.oracleRate;
        }

        // (currentTs - previousTs) / timeWindow
        uint256 lastTradeWeight = timeDiff.divDown(market.rateOracleTimeWindow);

        // 1 - (currentTs - previousTs) / timeWindow
        uint256 oracleWeight = FixedPoint.ONE - lastTradeWeight;

        uint256 newOracleRate = market.lastTradeTime.mulDown(lastTradeWeight) +
            market.oracleRate.mulDown(oracleWeight);

        market.oracleRate = newOracleRate;
        return market.oracleRate;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    ///                                    Utility functions                                    ////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function getTimeToExpiry(MarketParameters memory market) internal view returns (uint256) {
        unchecked {
            require(block.timestamp <= market.expiry, "market expired");
            return block.timestamp - market.expiry;
        }
    }

    function deepCloneMarket(MarketParameters memory marketImmutable)
        internal
        pure
        returns (MarketParameters memory market)
    {
        market.totalOt = marketImmutable.totalOt;
        market.totalScy = marketImmutable.totalScy;
        market.totalLp = marketImmutable.totalLp;
        market.scyRate = marketImmutable.scyRate;
        market.oracleRate = marketImmutable.oracleRate;
        market.scalarRoot = marketImmutable.scalarRoot;
        market.feeRateRoot = marketImmutable.feeRateRoot;
        market.anchorRoot = marketImmutable.anchorRoot;
        market.rateOracleTimeWindow = marketImmutable.rateOracleTimeWindow;
        market.expiry = marketImmutable.expiry;
        market.reserveFeePercent = marketImmutable.reserveFeePercent;
        market.lastImpliedRate = marketImmutable.lastImpliedRate;
        market.lastTradeTime = marketImmutable.lastTradeTime;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    ///                                Approx functions                                ///
    //////////////////////////////////////////////////////////////////////////////////////

    function approxSwapExactSCYForOt(
        MarketParameters memory marketImmutable,
        uint256 exactSCYIn,
        uint256 timeToExpiry,
        uint256 netOtOutGuessMin,
        uint256 netOtOutGuessMax
    ) internal pure returns (uint256 netOtOut) {
        require(exactSCYIn > 0, "invalid scy in");
        require(
            netOtOutGuessMin >= 0 && netOtOutGuessMax >= 0 && netOtOutGuessMin <= netOtOutGuessMax,
            "invalid guess"
        );

        uint256 low = netOtOutGuessMin;
        uint256 high = netOtOutGuessMax;
        bool isAcceptableAnswerExisted;

        while (low != high) {
            uint256 currentOtOutGuess = (low + high + 1) / 2;
            MarketParameters memory market = deepCloneMarket(marketImmutable);

            (uint256 netSCYNeed, ) = calcSCYForExactOt(market, currentOtOutGuess, timeToExpiry);
            bool isResultAcceptable = (netSCYNeed <= exactSCYIn);
            if (isResultAcceptable) {
                low = currentOtOutGuess;
                isAcceptableAnswerExisted = true;
            } else high = currentOtOutGuess - 1;
        }

        require(isAcceptableAnswerExisted, "guess fail");
        netOtOut = low;
    }

    function approxSwapOtForExactSCY(
        MarketParameters memory marketImmutable,
        uint256 exactSCYOut,
        uint256 timeToExpiry,
        uint256 netOtInGuessMin,
        uint256 netOtInGuessMax
    ) internal pure returns (uint256 netOtIn) {
        require(exactSCYOut > 0, "invalid scy in");
        require(
            netOtInGuessMin >= 0 && netOtInGuessMax >= 0 && netOtInGuessMin <= netOtInGuessMax,
            "invalid guess"
        );

        uint256 low = netOtInGuessMin;
        uint256 high = netOtInGuessMax;
        bool isAcceptableAnswerExisted;

        while (low != high) {
            uint256 currentOtInGuess = (low + high) / 2;
            MarketParameters memory market = deepCloneMarket(marketImmutable);

            (uint256 netSCYToAccount, ) = calcExactOtForSCY(
                market,
                currentOtInGuess,
                timeToExpiry
            );
            bool isResultAcceptable = (netSCYToAccount >= exactSCYOut);
            if (isResultAcceptable) {
                high = currentOtInGuess;
                isAcceptableAnswerExisted = true;
            } else {
                low = currentOtInGuess + 1;
            }
        }

        require(isAcceptableAnswerExisted, "guess fail");
        netOtIn = high;
    }

    function approxSwapExactSCYForYt(
        MarketParameters memory marketImmutable,
        uint256 exactSCYIn,
        uint256 timeToExpiry,
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax
    ) internal pure returns (uint256 netYtOut) {
        require(exactSCYIn > 0, "invalid scy in");
        require(netYtOutGuessMin >= 0 && netYtOutGuessMax >= 0, "invalid guess");

        uint256 low = netYtOutGuessMin;
        uint256 high = netYtOutGuessMax;
        bool isAcceptableAnswerExisted;

        while (low != high) {
            uint256 currentYtOutGuess = (low + high + 1) / 2;
            MarketParameters memory market = deepCloneMarket(marketImmutable);

            int256 otToAccount = currentYtOutGuess.neg();
            (int256 scyReceived, ) = calcTrade(market, otToAccount, timeToExpiry);

            int256 totalScyToMintYo = scyReceived + exactSCYIn.Int();

            int256 netYoFromSCY = SCYUtils.scyToAsset(market.scyRate, totalScyToMintYo);

            bool isResultAcceptable = (netYoFromSCY.Uint() >= currentYtOutGuess);

            if (isResultAcceptable) {
                low = currentYtOutGuess;
                isAcceptableAnswerExisted = true;
            } else high = currentYtOutGuess - 1;
        }

        require(isAcceptableAnswerExisted, "guess fail");
        netYtOut = low;
    }
}
