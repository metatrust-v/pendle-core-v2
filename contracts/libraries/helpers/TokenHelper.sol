// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract TokenHelper {
    using SafeERC20 for IERC20;
    address internal constant NATIVE = address(0);

    function _transferIn(
        address token,
        address from,
        uint256 amount
    ) internal {
        if (amount == 0 || token == NATIVE) return;
        IERC20(token).safeTransferFrom(from, address(this), amount);
    }

    function _transferOut(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (amount == 0) return;
        if (token == NATIVE) {
            (bool success, ) = to.call{ value: amount }("");
            require(success, "eth send failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    function _transferOut(
        address[] memory tokens,
        address to,
        uint256[] memory amounts
    ) internal {
        uint256 numTokens = tokens.length;
        require(numTokens == amounts.length, "length mismatch");
        for (uint256 i = 0; i < numTokens; ) {
            _transferOut(tokens[i], to, amounts[i]);
            unchecked {
                i++;
            }
        }
    }

    function _transferOutMaxMulti(
        address token,
        uint256 totalAmount,
        address[] memory tos,
        uint256[] memory maxAmounts
    ) internal returns (uint256 leftover) {
        uint256 numTos = tos.length;
        require(numTos == maxAmounts.length, "invalid length");

        leftover = totalAmount;
        for (uint256 i = 0; i < numTos; ) {
            uint256 maxAmount = maxAmounts[i];
            if (maxAmount > leftover) {
                maxAmount = leftover;
            }
            _transferOut(token, tos[i], maxAmount);
            unchecked {
                leftover -= maxAmount;
                if (leftover == 0) break;
                i++;
            }
        }
    }

    function _selfBalance(address token) internal view returns (uint256) {
        return (token == NATIVE) ? address(this).balance : IERC20(token).balanceOf(address(this));
    }

    function _selfBalances(address[] memory tokens)
        internal
        view
        returns (uint256[] memory balances)
    {
        uint256 length = tokens.length;
        balances = new uint256[](length);
        for (uint256 i = 0; i < length; ) {
            balances[i] = _selfBalance(tokens[i]);
            unchecked {
                i++;
            }
        }
    }

    /// @notice Approves the stipulated contract to spend the given allowance in the given token
    /// @dev Errors with 'SA' if transfer fails
    /// @param token The contract address of the token to be approved
    /// @param to The target of the approval
    /// @param value The amount of the given token the target will be allowed to spend
    function _safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Safe Approve");
    }
}
