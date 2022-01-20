// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.0;

import "./LogExpMath.sol";
import "../helpers/PendleErrors.sol";

/* solhint-disable private-vars-leading-underscore */

library FixedPoint {
    uint256 internal constant ONE = 1e18; // 18 decimal places
    uint256 internal constant MAX_POW_RELATIVE_ERROR = 10000; // 10^(-14)

    // Minimum base for the power function when the exponent is 'free' (larger than ONE).
    uint256 internal constant MIN_POW_BASE_FREE_EXPONENT = 0.7e18;

    function subMax0(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a >= b ? a - b : 0);
    }

    function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 product = a * b;
        return product / ONE;
    }

    function mulDown(int256 a, int256 b) internal pure returns (int256) {
        int256 product = a * b;
        return product / toInt(ONE);
    }

    function mulDown(int256 a, uint256 b) internal pure returns (int256) {
        return mulDown(a, toInt(b));
    }

    function mulDown(uint256 a, int256 b) internal pure returns (int256) {
        return mulDown(toInt(a), b);
    }

    function mulUp(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 product = a * b;

        if (product == 0) {
            return 0;
        } else {
            // The traditional divUp formula is:
            // divUp(x, y) := (x + y - 1) / y
            // To avoid intermediate overflow in the addition, we distribute the division and get:
            // divUp(x, y) := (x - 1) / y + 1
            // Note that this requires x != 0, which we already tested for.

            return ((product - 1) / ONE) + 1;
        }
    }

    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        } else {
            uint256 aInflated = a * ONE;
            return aInflated / b;
        }
    }

    function divDown(int256 a, int256 b) internal pure returns (int256) {
        if (a == 0) {
            return 0;
        } else {
            int256 aInflated = a * toInt(ONE);
            return aInflated / b;
        }
    }

    function divDown(uint256 a, int256 b) internal pure returns (int256) {
        return divDown(toInt(a), b);
    }

    function divDown(int256 a, uint256 b) internal pure returns (int256) {
        return divDown(a, toInt(b));
    }

    function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        } else {
            uint256 aInflated = a * ONE;
            // The traditional divUp formula is:
            // divUp(x, y) := (x + y - 1) / y
            // To avoid intermediate overflow in the addition, we distribute the division and get:
            // divUp(x, y) := (x - 1) / y + 1
            // Note that this requires x != 0, which we already tested for.

            return ((aInflated - 1) / b) + 1;
        }
    }

    /**
     * @dev Returns x^y, assuming both are fixed point numbers, rounding down. The result is guaranteed to not be above
     * the true value (that is, the error function expected - actual is always positive).
     */
    function powDown(uint256 x, uint256 y) internal pure returns (uint256) {
        uint256 raw = LogExpMath.pow(x, y);
        uint256 maxError = mulUp(raw, MAX_POW_RELATIVE_ERROR) + 1;

        if (raw < maxError) {
            return 0;
        } else {
            return raw - maxError;
        }
    }

    /**
     * @dev Returns x^y, assuming both are fixed point numbers, rounding up. The result is guaranteed to not be below
     * the true value (that is, the error function expected - actual is always negative).
     */
    function powUp(uint256 x, uint256 y) internal pure returns (uint256) {
        uint256 raw = LogExpMath.pow(x, y);
        uint256 maxError = mulUp(raw, MAX_POW_RELATIVE_ERROR) + 1;

        return raw + maxError;
    }

    /**
     * @dev Returns the complement of a value (1 - x), capped to 0 if x is larger than 1.
     *
     * Useful when computing the complement for values with some level of relative error, as it strips this error and
     * prevents intermediate negative values.
     */
    function complement(uint256 x) internal pure returns (uint256) {
        return (x < ONE) ? (ONE - x) : 0;
    }

    function toUint(int256 x) internal pure returns (uint256) {
        require(x >= 0, "INVALID_CAST");
        return uint256(x);
    }

    function toInt(uint256 x) internal pure returns (int256) {
        require(x <= uint256(type(int256).max), "INVALID_CAST");
        return int256(x);
    }

    function neg(int256 x) internal pure returns (int256) {
        return -x;
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x > y ? x : y);
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x < y ? x : y);
    }
}
