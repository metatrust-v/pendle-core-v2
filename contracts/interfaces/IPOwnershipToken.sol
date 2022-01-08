// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import "./IPBaseToken.sol";

interface IPOwnershipToken is IPBaseToken {
    function LYT() external returns (address);

    function burnByYT(address user, uint256 amount) external;

    function mintByYT(address user, uint256 amount) external;
}
