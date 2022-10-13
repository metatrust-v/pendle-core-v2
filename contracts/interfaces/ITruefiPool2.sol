// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ITruefiPool2 is IERC20Metadata {
    function token() external view returns (address);

    function join(uint256 amount) external;

    function liquidExit(uint256 amount) external;

    function poolValue() external view returns (uint256);

    function joiningFee() external view returns (uint256);

    function liquidExitPenalty(uint256 amount) external view returns (uint256);
}
