// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// goal: make this ultra simple
interface IPVault {
    // only work with ERC20 for nowv
    function depositWithTransfer(
        address to,
        address token,
        uint256 amount
    ) external;

    function depositNoTransfer(
        address to,
        address token,
        uint256 amount
    ) external;

    function withdrawTo(
        address to,
        address token,
        uint256 amount
    ) external;

    function flash(
        address recipient,
        address[] calldata tokens,
        uint256[] calldata amountsToLoan,
        bytes calldata data
    ) external;

    function callerBalance(address token) external view returns (uint256 res);
}
