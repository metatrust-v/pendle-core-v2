// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Base/PendleBaseToken.sol";
import "../interfaces/IPMarketCallback.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../interfaces/IPLiquidYieldToken.sol";
import "../interfaces/IPMarket.sol";

import "../libraries/math/LogExpMath.sol";
import "../libraries/math/FixedPoint.sol";

// solhint-disable reason-string
contract PendleMarket is PendleBaseToken, IPMarket {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using LogExpMath for uint256;
    // make it ultra simple

    // careful, the reserve of the market shouldn't be interferred by external factors
    string private constant NAME = "Pendle Market";
    string private constant SYMBOL = "PENDLE-LPT";
    uint256 private constant MINIMUM_LIQUIDITY = 10**3;
    uint8 private constant DECIMALS = 18;
    int256 internal constant RATE_PRECISION = 1e9;

    address public immutable OT;
    address public immutable LYT;

    uint256 public reserveOT;
    uint256 public reserveLYT;

    uint256 public immutable scalarRoot;
    uint256 public immutable feeRateRoot; // allow fee to be changable

    int256 public savedAnchorRate;
    uint256 public start;
    uint256 public marketDuration;
    uint256 public savedIntRate;

    constructor(
        address _OT,
        uint256 _feeRateRoot,
        uint256 _scalarRoot,
        int256 _anchorRoot
    ) PendleBaseToken(NAME, SYMBOL, 18, IPOwnershipToken(_OT).expiry()) {
        OT = _OT;
        LYT = IPOwnershipToken(_OT).LYT();
        feeRateRoot = _feeRateRoot;
        scalarRoot = _scalarRoot;
        savedAnchorRate = _anchorRoot;
    }

    function mint(address to) external returns (uint256 liquidity) {
        require(block.timestamp < expiry, "MARKET_EXPIRED");

        uint256 amountOT = _selfBalance(OT) - reserveOT;
        uint256 amountLYT = _selfBalance(LYT) - reserveLYT;

        if (totalSupply() == 0) {
            start = block.timestamp;
            marketDuration = expiry - start;
            liquidity = amountLYT.mulDown(_lytExchangeRate()) - MINIMUM_LIQUIDITY;
            _mint(address(1), MINIMUM_LIQUIDITY);
        } else {
            liquidity = FixedPoint.min(
                (amountOT * totalSupply()) / reserveOT,
                (amountLYT * totalSupply()) / reserveLYT
            );
        }
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _updateReserve();
    }

    function burn(address to) external returns (uint256 amountOT, uint256 amountLYT) {
        uint256 liquidity = balanceOf(address(this));
        amountOT = (liquidity * reserveOT) / totalSupply();
        amountLYT = (liquidity * reserveLYT) / totalSupply();
        require(amountOT > 0 && amountLYT > 0, "INSUFFICIENT_LIQUIDITY_BURNED");

        IERC20(OT).transfer(to, amountOT);
        IERC20(LYT).transfer(to, amountLYT);

        _burn(address(this), liquidity);
        _updateReserve();
    }

    // doing call back?
    function swap(
        address recipient,
        int256 amountOTIn,
        bytes calldata data
    ) external returns (int256 amountLYTIn) {
        require(block.timestamp < expiry, "MARKET_EXPIRED");
        require(reserveOT.toInt() + amountOTIn > 0, "INSUFFICIENT_LIQUIDITY");

        savedAnchorRate = getAnchorRate();
        uint256 pTrade = getPTrade(amountOTIn);

        int256 feeRate = getFeeRate().toInt();
        feeRate = (amountOTIn > 0 ? feeRate : -feeRate);

        int256 excRateTrade = getExcRate(pTrade).toInt() + feeRate;

        require(excRateTrade >= (FixedPoint.ONE).toInt(), "NEGATIVE_RATE");

        int256 amountAccUnitsIn = amountOTIn.divDown(excRateTrade).neg();

        // the exchangeRate is get twice, not nice
        amountLYTIn = amountAccUnitsIn.divDown(_lytExchangeRate());

        if (amountOTIn > 0) {
            // need to pull OT & push LYT
            uint256 amountLYTOut = amountLYTIn.neg().toUint();
            IERC20(LYT).transfer(recipient, amountLYTOut);
            IPMarketCallback(msg.sender).callback(
                address(LYT),
                amountLYTOut,
                address(OT),
                amountOTIn.toUint(),
                data
            );
            require(_selfBalance(OT) - reserveOT >= amountOTIn.toUint());
        } else {
            // need to pull LYT & push OT
            uint256 amountOTOut = amountOTIn.neg().toUint();
            IERC20(OT).transfer(recipient, amountOTOut);
            IPMarketCallback(msg.sender).callback(
                address(OT),
                amountOTOut,
                address(LYT),
                amountLYTIn.toUint(),
                data
            );
            require(_selfBalance(LYT) - reserveLYT >= amountLYTIn.toUint());
        }

        savedIntRate = getIntRate();
        _updateReserve();
        // TODO: also need to transfer the money to treasury
    }

    function getPTrade(int256 amountOTIn) public returns (uint256 pTrade) {
        uint256 numer = uint256(int256(reserveOT) + amountOTIn);
        uint256 denom = reserveOT + getTotalAccUnits();
        pTrade = numer.divDown(denom);
    }

    function getIntRate() public returns (uint256 rate) {
        // IntRate = (ExcRate - 1) * periodSize / timeToMaturity
        rate =
            ((getExcRate(getProportion()) - FixedPoint.ONE) * marketDuration) /
            getTimeToExpiry();
    }

    function getTotalAccUnits() public returns (uint256 totalAccUnits) {
        totalAccUnits = reserveLYT.mulDown(_lytExchangeRate());
    }

    function getProportion() public returns (uint256 proportion) {
        proportion = reserveOT.divDown(reserveOT + getTotalAccUnits());
    }

    function getAnchorRate() public returns (int256 anchorRate) {
        int256 interestRateDiff = int256(getIntRate()) - int256(savedIntRate);
        anchorRate =
            savedAnchorRate -
            (interestRateDiff * int256(getTimeToExpiry())) /
            int256(marketDuration);
    }

    function getFeeRate() public view returns (uint256 feeRate) {
        feeRate = (feeRateRoot * getTimeToExpiry()) / marketDuration;
    }

    function getExcRate(uint256 proportion) public view returns (uint256 rate) {
        uint256 fracPro = proportion.divDown(FixedPoint.ONE - proportion);
        int256 lnPro = LogExpMath.ln(int256(fracPro));
        uint256 scalar = getScalar();
        // ExcRate = 1 / scalar * ln(proportion/(1-proportion)) + anchor
        // = ln(proportion/(1-proportion)) / scalar + anchor

        int256 intRate = lnPro.divDown(scalar) + savedAnchorRate;
        require(intRate >= LogExpMath.ONE_18, "NEGATIVE_RATE");

        rate = uint256(intRate);
    }

    function getScalar() public view returns (uint256 curScalar) {
        return (scalarRoot * marketDuration) / getTimeToExpiry();
    }

    function getTimeToExpiry() public view returns (uint256 timeToExpiry) {
        timeToExpiry = expiry - block.timestamp;
    }

    // may add this, but gas may be expensive
    // function getAmountOTOutFromLYT(uint256 amountLYTIn)
    //     public
    //     pure
    //     returns (uint256 amountOTOut)
    // {}

    function _updateReserve() internal {
        reserveLYT = _selfBalance(LYT);
        reserveOT = _selfBalance(OT);
    }

    function _lytExchangeRate() internal returns (uint256 rate) {
        rate = IPLiquidYieldToken(LYT).exchangeRateCurrent();
    }

    function _selfBalance(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
