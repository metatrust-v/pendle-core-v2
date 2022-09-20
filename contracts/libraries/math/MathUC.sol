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

pragma solidity 0.8.15;

/* solhint-disable private-vars-leading-underscore, reason-string */

library MathUC {
    uint256 internal constant ONE = 1e18; // 18 decimal places
    int256 internal constant IONE = 1e18; // 18 decimal places

    function subMax0(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            return (a >= b ? a - b : 0);
        }
    }

    function subNoNeg(int256 a, int256 b) internal pure returns (int256) {
        require(a >= b, "negative");
        unchecked {
            return a - b;
        }
    }

    function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            return (a * b) / ONE;
        }
    }

    function mulDown(int256 a, int256 b) internal pure returns (int256) {
        unchecked {
            return (a * b) / IONE;
        }
    }

    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            return (a * ONE) / b;
        }
    }

    function divDown(int256 a, int256 b) internal pure returns (int256) {
        unchecked {
            return (a * IONE) / b;
        }
    }

    function rawDivUp(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            return (a + b - 1) / b;
        }
    }

    // @author Uniswap
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        unchecked {
            if (y > 3) {
                z = y;
                uint256 x = y / 2 + 1;
                while (x < z) {
                    z = x;
                    x = (y / x + x) / 2;
                }
            } else if (y != 0) {
                z = 1;
            }
        }
    }

    function abs(int256 x) internal pure returns (uint256) {
        unchecked {
            return uint256(x > 0 ? x : -x);
        }
    }

    function neg(int256 x) internal pure returns (int256) {
        unchecked {
            return x * (-1);
        }
    }

    function neg(uint256 x) internal pure returns (int256) {
        unchecked {
            return Int(x) * (-1);
        }
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x > y ? x : y);
    }

    function max(int256 x, int256 y) internal pure returns (int256) {
        return (x > y ? x : y);
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x < y ? x : y);
    }

    function min(int256 x, int256 y) internal pure returns (int256) {
        return (x < y ? x : y);
    }

    /*///////////////////////////////////////////////////////////////
                               SIGNED CASTS
    //////////////////////////////////////////////////////////////*/

    function Int(uint256 x) internal pure returns (int256) {
        return int256(x);
    }

    function Int128(int256 x) internal pure returns (int128) {
        return int128(x);
    }

    /*///////////////////////////////////////////////////////////////
                               UNSIGNED CASTS
    //////////////////////////////////////////////////////////////*/

    function Uint(int256 x) internal pure returns (uint256) {
        return uint256(x);
    }

    function Uint32(uint256 x) internal pure returns (uint32) {
        return uint32(x);
    }

    function Uint112(uint256 x) internal pure returns (uint112) {
        return uint112(x);
    }

    function Uint96(uint256 x) internal pure returns (uint96) {
        return uint96(x);
    }

    function Uint128(uint256 x) internal pure returns (uint128) {
        return uint128(x);
    }

    function isAApproxB(
        uint256 a,
        uint256 b,
        uint256 eps
    ) internal pure returns (bool) {
        return (isAGreaterApproxB(a, b, eps) || isASmallerApproxB(a, b, eps));
    }

    function isAGreaterApproxB(
        uint256 a,
        uint256 b,
        uint256 eps
    ) internal pure returns (bool) {
        unchecked {
            return a >= b && a <= mulDown(b, ONE + eps);
        }
    }

    function isASmallerApproxB(
        uint256 a,
        uint256 b,
        uint256 eps
    ) internal pure returns (bool) {
        unchecked {
            return a <= b && a >= mulDown(b, ONE - eps);
        }
    }
}
