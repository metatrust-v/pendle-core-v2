// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
pragma abicoder v2;
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";

interface IVEPendleToken {
    function pendle() external view returns (IERC20);

    function balanceOf(address user) external view returns (uint256);

    function totalSupply() external returns (uint256);
}
