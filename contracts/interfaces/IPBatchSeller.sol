// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface IPBatchSeller {
    function buyPtWithExactToken(
        address receiver,
        uint256 netTokenIn,
        uint256 minPtOut
    ) external returns (uint256 netPtOut);

    function buyExactPt(
        address receiver,
        uint256 netPtOut,
        uint256 maxTokenIn
    ) external returns (uint256 netTokenIn);

    function price() external returns (uint256);

    function calcPtOut(uint256 netTokenIn) external view returns (uint256 netPtOut);

    function calcTokenIn(uint256 netPtOut) external view returns (uint256 netTokenIn);
}
