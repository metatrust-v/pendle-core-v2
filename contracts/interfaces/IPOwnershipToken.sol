// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import "./IPBaseToken.sol";

interface IPOwnershipToken is IPBaseToken {
    function initialize(address _YT) external;

    function burnByYT(address user, uint256 amount) external;

    function mintByYT(address user, uint256 amount) external;

    function LYT() external view returns (address);

    function YT() external view returns (address);
}
