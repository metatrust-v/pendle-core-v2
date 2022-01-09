// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import "openzeppelin-solidity/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IPBaseToken is IERC20Metadata {
    function expiry() external returns (uint256);
}
