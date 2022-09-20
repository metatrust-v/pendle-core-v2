// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

library SCYUtilsUC {
    uint256 internal constant ONE = 1e18;

    function scyToAsset(uint256 exchangeRate, uint256 scyAmount) internal pure returns (uint256) {
        unchecked {
            return (scyAmount * exchangeRate) / ONE;
        }
    }

    function scyToAssetUp(uint256 exchangeRate, uint256 scyAmount)
        internal
        pure
        returns (uint256)
    {
        unchecked {
            return (scyAmount * exchangeRate + ONE - 1) / ONE;
        }
    }

    function assetToScy(uint256 exchangeRate, uint256 assetAmount)
        internal
        pure
        returns (uint256)
    {
        unchecked {
            return (assetAmount * ONE) / exchangeRate;
        }
    }

    function assetToScyUp(uint256 exchangeRate, uint256 assetAmount)
        internal
        pure
        returns (uint256)
    {
        unchecked {
            return (assetAmount * ONE + exchangeRate - 1) / exchangeRate;
        }
    }
}
