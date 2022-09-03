// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../../interfaces/IPMessageReceiverApp.sol";
import "../../../periphery/BoringOwnableUpgradeable.sol";

// solhint-disable no-empty-blocks
/// This contract is upgradable because
/// - its constructor only sets immutable variables
/// - it has storage gaps for safe addition of future variables
/// - it inherits only upgradable contract
abstract contract PendleReceiverUpg is IPMessageReceiverApp, BoringOwnableUpgradeable {
    address public immutable pendleMsgReceiveEndpoint;

    uint256[100] private __gap;

    constructor(address _pendleMsgReceiveEndpoint) {
        pendleMsgReceiveEndpoint = _pendleMsgReceiveEndpoint;
    }

    function executeMessage(bytes calldata message) external payable {
        require(msg.sender == pendleMsgReceiveEndpoint, "only pendle message receive endpoint");
        _executeMessage(message);
    }

    function _executeMessage(bytes memory message) internal virtual;
}
