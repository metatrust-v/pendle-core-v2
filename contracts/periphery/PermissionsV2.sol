// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/IPGovernanceManager.sol";
import "../interfaces/IPPermissionsV2.sol";

abstract contract PermissionsV2 is IPermissionsV2 {
    address public immutable governanceManager;

    modifier onlyGovernance() {
        require(msg.sender == _governance(), "ONLY_GOVERNANCE");
        _;
    }

    constructor(address _governanceManager) {
        require(_governanceManager != address(0), "ZERO_ADDRESS");
        governanceManager = _governanceManager;
    }

    function _governance() internal view returns (address) {
        return IPGovernanceManager(governanceManager).governance();
    }
}
