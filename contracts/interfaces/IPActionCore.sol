// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../libraries/math/MarketApproxLib.sol";

interface IPActionCore {
    event AddLiquidity(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        uint256 scyUsed,
        uint256 ptUsed,
        uint256 lpOut
    );

    event RemoveLiquidity(
        address indexed caller,
        address indexed market,
        address receiver,
        uint256 lpIn,
        uint256 amountPTOut,
        uint256 amountSCYOut
    );

    event SwapPtAndScy(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        int256 amountPtToAccount,
        int256 amountScyToAccount
    );

    event SwapPtAndRawToken(
        address indexed caller,
        address indexed market,
        address indexed rawToken,
        address receiver,
        int256 amountPtToAccount,
        int256 amountRawTokenToAccount
    );

    event MintScyFromRawToken(
        address indexed caller,
        address indexed receiver,
        address indexed SCY,
        address rawTokenIn,
        uint256 netRawTokenIn,
        uint256 netScyOut
    );

    event RedeemScyToRawToken(
        address indexed caller,
        address indexed receiver,
        address indexed SCY,
        uint256 netScyIn,
        address rawTokenOut,
        uint256 netRawTokenOut
    );

    event MintPyFromRawToken(
        address indexed caller,
        address indexed receiver,
        address indexed YT,
        address rawTokenIn,
        uint256 netRawTokenIn,
        uint256 netPyOut
    );

    event RedeemPyToRawToken(
        address indexed caller,
        address indexed receiver,
        address indexed YT,
        uint256 netPyIn,
        address rawTokenOut,
        uint256 netRawTokenOut
    );

    function addLiquidity(
        address receiver,
        address market,
        uint256 scyDesired,
        uint256 ptDesired,
        uint256 minLpOut
    )
        external
        returns (
            uint256 netLpOut,
            uint256 scyUsed,
            uint256 ptUsed
        );

    function removeLiquidity(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 ptOutMin
    ) external returns (uint256 netScyOut, uint256 netPtOut);

    function swapExactPtForScy(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minScyOut
    ) external returns (uint256 netScyOut);

    function swapPtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        uint256 maxPtIn,
        ApproxParams memory guessPtIn
    ) external returns (uint256 netPtIn);

    function swapScyForExactPt(
        address receiver,
        address market,
        uint256 exactPtOut,
        uint256 maxScyIn
    ) external returns (uint256 netScyIn);

    function swapExactScyForPt(
        address receiver,
        address market,
        uint256 exactScyIn,
        uint256 minPtOut,
        ApproxParams memory guessPtOut
    ) external returns (uint256 netPtOut);

    function mintScyFromRawToken(
        address receiver,
        address SCY,
        uint256 netRawTokenIn,
        uint256 minScyOut,
        address[] calldata path
    ) external returns (uint256 netScyOut);

    function redeemScyToRawToken(
        address receiver,
        address SCY,
        uint256 netScyIn,
        uint256 minRawTokenOut,
        address[] memory path
    ) external returns (uint256 netRawTokenOut);

    function mintPyFromRawToken(
        address receiver,
        address YT,
        uint256 netRawTokenIn,
        uint256 minPyOut,
        address[] calldata path
    ) external returns (uint256 netPyOut);

    function redeemPyToRawToken(
        address receiver,
        address YT,
        uint256 netPyIn,
        uint256 minRawTokenOut,
        address[] memory path
    ) external returns (uint256 netRawTokenOut);

    function swapExactRawTokenForPt(
        address receiver,
        address market,
        uint256 exactRawTokenIn,
        uint256 minPtOut,
        address[] calldata path,
        ApproxParams memory guessPtOut
    ) external returns (uint256 netPtOut);

    function swapExactPtForRawToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minRawTokenOut,
        address[] calldata path
    ) external returns (uint256 netRawTokenOut);

    function redeemDueInterestAndRewards(
        address user,
        address[] calldata scys,
        address[] calldata yts,
        address[] calldata markets
    )
        external
        returns (
            uint256[][] memory scyRewards,
            uint256[] memory ytInterests,
            uint256[][] memory ytRewards,
            uint256[][] memory marketRewards
        );
}
