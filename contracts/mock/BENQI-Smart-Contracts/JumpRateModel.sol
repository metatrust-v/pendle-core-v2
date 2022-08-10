pragma solidity 0.8.15;

import "./InterestRateModel.sol";
import "./SafeMath.sol";

/**
 * @title Benqi's JumpRateModel Contract
 * @author Benqi
 */
contract JumpRateModel is InterestRateModel {
    using SafeMath for uint256;

    event NewInterestParams(
        uint256 baseRatePerTimestamp,
        uint256 multiplierPerTimestamp,
        uint256 jumpMultiplierPerTimestamp,
        uint256 kink
    );

    /**
     * @notice The approximate number of timestamps per year that is assumed by the interest rate model
     */
    uint256 public constant timestampsPerYear = 31536000;

    /**
     * @notice The multiplier of utilization rate that gives the slope of the interest rate
     */
    uint256 public multiplierPerTimestamp;

    /**
     * @notice The base interest rate which is the y-intercept when utilization rate is 0
     */
    uint256 public baseRatePerTimestamp;

    /**
     * @notice The multiplierPerTimestamp after hitting a specified utilization point
     */
    uint256 public jumpMultiplierPerTimestamp;

    /**
     * @notice The utilization point at which the jump multiplier is applied
     */
    uint256 public kink;

    /**
     * @notice Construct an interest rate model
     * @param baseRatePerYear The approximate target base APR, as a mantissa (scaled by 1e18)
     * @param multiplierPerYear The rate of increase in interest rate wrt utilization (scaled by 1e18)
     * @param jumpMultiplierPerYear The multiplierPerTimestamp after hitting a specified utilization point
     * @param kink_ The utilization point at which the jump multiplier is applied
     */
    constructor(
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 kink_
    ) public {
        baseRatePerTimestamp = baseRatePerYear.mul(1e18).div(timestampsPerYear).div(1e18);
        multiplierPerTimestamp = multiplierPerYear.mul(1e18).div(timestampsPerYear).div(1e18);
        jumpMultiplierPerTimestamp = jumpMultiplierPerYear.mul(1e18).div(timestampsPerYear).div(
            1e18
        );
        kink = kink_;

        emit NewInterestParams(
            baseRatePerTimestamp,
            multiplierPerTimestamp,
            jumpMultiplierPerTimestamp,
            kink
        );
    }

    /**
     * @notice Calculates the utilization rate of the market: `borrows / (cash + borrows - reserves)`
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market (currently unused)
     * @return The utilization rate as a mantissa between [0, 1e18]
     */
    function utilizationRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public pure returns (uint256) {
        // Utilization rate is 0 when there are no borrows
        if (borrows == 0) {
            return 0;
        }

        return borrows.mul(1e18).div(cash.add(borrows).sub(reserves));
    }

    /**
     * @notice Calculates the current borrow rate per timestmp, with the error code expected by the market
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market
     * @return The borrow rate percentage per timestmp as a mantissa (scaled by 1e18)
     */
    function getBorrowRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public view override returns (uint256) {
        uint256 util = utilizationRate(cash, borrows, reserves);

        if (util <= kink) {
            return util.mul(multiplierPerTimestamp).div(1e18).add(baseRatePerTimestamp);
        } else {
            uint256 normalRate = kink.mul(multiplierPerTimestamp).div(1e18).add(
                baseRatePerTimestamp
            );
            uint256 excessUtil = util.sub(kink);
            return excessUtil.mul(jumpMultiplierPerTimestamp).div(1e18).add(normalRate);
        }
    }

    /**
     * @notice Calculates the current supply rate per timestmp
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market
     * @param reserveFactorMantissa The current reserve factor for the market
     * @return The supply rate percentage per timestmp as a mantissa (scaled by 1e18)
     */
    function getSupplyRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactorMantissa
    ) public view override returns (uint256) {
        uint256 oneMinusReserveFactor = uint256(1e18).sub(reserveFactorMantissa);
        uint256 borrowRate = getBorrowRate(cash, borrows, reserves);
        uint256 rateToPool = borrowRate.mul(oneMinusReserveFactor).div(1e18);
        return utilizationRate(cash, borrows, reserves).mul(rateToPool).div(1e18);
    }
}
