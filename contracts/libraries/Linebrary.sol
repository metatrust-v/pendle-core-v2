// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
pragma abicoder v2;

struct Line {
    uint256 slope;
    uint256 bias;
}

library LineHelper {
    function add(Line memory a, Line memory b) internal pure returns (Line memory res) {
        res.slope = a.slope + b.slope;
        res.bias = a.bias + b.bias;
    }

    function sub(Line memory a, Line memory b) internal pure returns (Line memory res) {
        res.slope = a.slope - b.slope;
        res.bias = a.bias - b.bias;
    }

    function mul(Line memory a, uint256 b) internal pure returns (Line memory res) {
        res.slope = a.slope * b;
        res.bias = a.bias * b;
    }

    function div(Line memory a, uint256 b) internal pure returns (Line memory res) {
        res.slope = a.slope / b;
        res.bias = a.bias / b;
    }

    function getValueAt(Line memory a, uint256 t) internal pure returns (uint256 res) {
        if (a.bias >= a.slope * t) {
            res = a.bias - a.slope * t;
        }
    }

    function getCurrentBalance(Line memory a) internal view returns (uint256 res) {
        res = LineHelper.getValueAt(a, block.timestamp);
    }

    function getExpiry(Line memory a) internal pure returns (uint256 res) {
        return a.bias / a.slope;
    }
}
