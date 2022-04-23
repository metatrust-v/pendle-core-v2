// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

abstract contract ActionType {
    enum ACTION_TYPE {
        AddLiquidity,
        RemoveLiquidity,
        SwapExactPtForScy,
        SwapScyForExactPt,
        SwapExactYtForScy,
        SwapSCYForExactYt,
        SwapExactScyForYt,
        SwapYtForExactScy
    }
}
