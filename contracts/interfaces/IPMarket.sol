// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./IPPrincipalToken.sol";
import "./IPYieldToken.sol";
import "../libraries/math/MarketMathCore.sol";

interface IPMarket is IERC20Metadata {
    event AddLiquidity(
        address indexed receiver,
        uint256 lpToAccount,
        uint256 scyUsed,
        uint256 ptUsed
    );

    event RemoveLiquidity(
        address indexed receiverScy,
        address indexed receiverPt,
        uint256 lpRemoved,
        uint256 scyToAccount,
        uint256 ptToAccount
    );

    event Swap(
        address indexed receiver,
        int256 ptToAccount,
        int256 scyToAccount,
        uint256 netScyToReserve
    );

    event UpdateImpliedRate(uint256 indexed timestamp, uint256 lnLastImpliedRate);

    function addLiquidity(
        address receiver,
        uint256 scyDesired,
        uint256 ptDesired,
        bytes calldata data
    )
        external
        returns (
            uint256 lpToAccount,
            uint256 scyUsed,
            uint256 ptUsed
        );

    function removeLiquidity(
        address receiverScy,
        address receiverPt,
        uint256 lpToRemove,
        bytes calldata data
    ) external returns (uint256 scyToAccount, uint256 ptToAccount);

    function swapExactPtForScy(
        address receiver,
        uint256 exactPtIn,
        bytes calldata data
    ) external returns (uint256 netScyOut, uint256 netScyToReserve);

    function swapScyForExactPt(
        address receiver,
        uint256 exactPtOut,
        bytes calldata data
    ) external returns (uint256 netScyIn, uint256 netScyToReserve);

    function redeemRewards(address user) external returns (uint256[] memory);

    function readState(bool updateRateOracle) external view returns (MarketState memory market);

    function readTokens()
        external
        view
        returns (
            ISuperComposableYield _SCY,
            IPPrincipalToken _PT,
            IPYieldToken _YT
        );

    function getRewardTokens() external view returns (address[] memory);

    function isExpired() external view returns (bool);
}
