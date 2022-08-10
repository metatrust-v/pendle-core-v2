pragma solidity 0.8.15;

abstract contract ComptrollerInterface {
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    bool public constant isComptroller = true;

    /*** Assets You Are In ***/

    function enterMarkets(address[] calldata qiTokens) external virtual returns (uint256[] memory);

    function exitMarket(address qiToken) external virtual returns (uint256);

    /*** Policy Hooks ***/

    function mintAllowed(
        address qiToken,
        address minter,
        uint256 mintAmount
    ) external virtual returns (uint256);

    function mintVerify(
        address qiToken,
        address minter,
        uint256 mintAmount,
        uint256 mintTokens
    ) external virtual;

    function redeemAllowed(
        address qiToken,
        address redeemer,
        uint256 redeemTokens
    ) external virtual returns (uint256);

    function redeemVerify(
        address qiToken,
        address redeemer,
        uint256 redeemAmount,
        uint256 redeemTokens
    ) external virtual;

    function borrowAllowed(
        address qiToken,
        address borrower,
        uint256 borrowAmount
    ) external virtual returns (uint256);

    function borrowVerify(
        address qiToken,
        address borrower,
        uint256 borrowAmount
    ) external virtual;

    function repayBorrowAllowed(
        address qiToken,
        address payer,
        address borrower,
        uint256 repayAmount
    ) external virtual returns (uint256);

    function repayBorrowVerify(
        address qiToken,
        address payer,
        address borrower,
        uint256 repayAmount,
        uint256 borrowerIndex
    ) external virtual;

    function liquidateBorrowAllowed(
        address qiTokenBorrowed,
        address qiTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) external virtual returns (uint256);

    function liquidateBorrowVerify(
        address qiTokenBorrowed,
        address qiTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount,
        uint256 seizeTokens
    ) external virtual;

    function seizeAllowed(
        address qiTokenCollateral,
        address qiTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external virtual returns (uint256);

    function seizeVerify(
        address qiTokenCollateral,
        address qiTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external virtual;

    function transferAllowed(
        address qiToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external virtual returns (uint256);

    function transferVerify(
        address qiToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external virtual;

    /*** Liquidity/Liquidation Calculations ***/

    function liquidateCalculateSeizeTokens(
        address qiTokenBorrowed,
        address qiTokenCollateral,
        uint256 repayAmount
    ) external view virtual returns (uint256, uint256);
}
