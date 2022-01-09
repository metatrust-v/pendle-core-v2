// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/IPGovernanceManager.sol";

contract PendleGovernanceManager is IPGovernanceManager {
    address public governance;

    event GovernanceTransferred(address indexed newGovernance, address indexed previousGovernance);

    modifier onlyGov() {
        require(msg.sender == governance, "ONLY_GOVERNANCE");
        _;
    }

    constructor() {
        _transferGovernance(msg.sender);
    }

    function transferGovernance(address newGovernance) external onlyGov {
        require(newGovernance != address(0), "ZERO_ADDRESS");
        _transferGovernance(newGovernance);
    }

    function _transferGovernance(address newGovernance) internal {
        address oldGovernance = governance;
        governance = newGovernance;
        emit GovernanceTransferred(oldGovernance, newGovernance);
    }
}
