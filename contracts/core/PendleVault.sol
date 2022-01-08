// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../libraries/math/FixedPoint.sol";
import "../interfaces/IPFlashCallBack.sol";
import "../interfaces/IPVault.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";

// goal: make this ultra simple
contract PendleVault is IPVault {
    using SafeERC20 for IERC20;
    using FixedPoint for uint256;
    mapping(address => uint256) public totalBalance;
    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => bool) public zeroFeeLoan;
    address public treasury; // move this treasury elsewhere

    uint256 public flashFee;

    // only work with ERC20 for nowv
    function depositWithTransfer(
        address to,
        address token,
        uint256 amount
    ) external {
        _incBalanceUser(to, token, amount);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    function depositNoTransfer(
        address to,
        address token,
        uint256 amount
    ) external {
        // must not under flashloan
        require(
            IERC20(token).balanceOf(address(this)) - totalBalance[token] >= amount,
            "INSUFFICIENT_BALANCE"
        );
        _incBalanceUser(to, token, amount);
    }

    // only work with ERC20 for nowv
    function withdrawTo(
        address to,
        address token,
        uint256 amount
    ) external {
        _decBalanceUser(msg.sender, token, amount);
        IERC20(token).safeTransfer(to, amount);
    }

    function flash(
        address recipient,
        address[] calldata tokens,
        uint256[] calldata amountsToLoan,
        bytes calldata data
    ) external {
        require(tokens.length == amountsToLoan.length, "INVALID_ARRAY");

        uint256[] memory amountsToPay = calcAmountsToPay(msg.sender, amountsToLoan);
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(recipient, amountsToLoan[i]);
        }
        IPFlashCallback(msg.sender).pendleFlashCallback(tokens, amountsToPay, data);

        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), amountsToPay[i]);
        }

        claimExcess(treasury, tokens);
    }

    // only governance
    // also must have functions to redeem LYT interests & withdrawable ...
    function modifyZeroFeeLoan(address[] calldata addr, bool[] calldata newState) external {
        require(addr.length == newState.length, "INVALID_ARRAY");
        for (uint256 i = 0; i < newState.length; i++) {
            zeroFeeLoan[addr[i]] = newState[i];
        }
    }

    function callerBalance(address token) external view returns (uint256 res) {
        res = balances[msg.sender][token];
    }

    function claimExcess(address to, address[] calldata tokens) public {
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 excess = IERC20(tokens[i]).balanceOf(address(this)) - totalBalance[tokens[i]];
            _incBalanceUser(to, tokens[i], excess);
        }
    }

    function calcAmountsToPay(address loaner, uint256[] calldata amountsToLoan)
        public
        view
        returns (uint256[] memory amountsToPay)
    {
        amountsToPay = amountsToLoan;
        if (zeroFeeLoan[loaner] == false) {
            for (uint256 i = 0; i < amountsToLoan.length; i++) {
                amountsToPay[i] = amountsToPay[i].mulUp(flashFee);
            }
        }
    }

    function _incBalanceUser(
        address user,
        address token,
        uint256 amount
    ) internal {
        totalBalance[token] += amount;
        balances[user][token] += amount;
    }

    function _decBalanceUser(
        address user,
        address token,
        uint256 amount
    ) internal {
        totalBalance[token] -= amount;
        balances[user][token] -= amount;
    }

    // function to redeem LYT interests here
}
