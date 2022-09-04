// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../../interfaces/ICelerMessageReceiverApp.sol";
import "../../../interfaces/IPMessageReceiverApp.sol";
import "../../../interfaces/ICelerMessageBus.sol";
import "../../../periphery/BoringOwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract PendleMsgReceiveEndpoint is
    ICelerMessageReceiverApp,
    Initializable,
    UUPSUpgradeable,
    BoringOwnableUpgradeable
{
    ICelerMessageBus public immutable celerMessageBus;
    address public immutable sendEndpointAddr;
    uint64 public immutable sendEndpointChainId;

    modifier onlyCelerMessageBus() {
        require(msg.sender == address(celerMessageBus), "only celer message bus");
        _;
    }

    modifier mustOriginateFromSendEndpoint(address srcAddress, uint64 srcChainId) {
        require(
            srcAddress == sendEndpointAddr && srcChainId == sendEndpointChainId,
            "message must be created by sendEndpoint"
        );
        _;
    }

    constructor(
        ICelerMessageBus _celerMessageBus,
        address _sendEndpointAddr,
        uint64 _sendEndpointChainId
    ) {
        celerMessageBus = _celerMessageBus;
        sendEndpointAddr = _sendEndpointAddr;
        sendEndpointChainId = _sendEndpointChainId;
    }

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    // @notice for Celer
    function executeMessage(
        address srcAddress,
        uint64 srcChainId,
        bytes calldata message,
        address /*_executor*/
    )
        external
        payable
        onlyCelerMessageBus
        mustOriginateFromSendEndpoint(srcAddress, srcChainId)
        returns (ExecutionStatus)
    {
        (address receiver, bytes memory actualMessage) = abi.decode(message, (address, bytes));
        IPMessageReceiverApp(receiver).executeMessage(actualMessage);
        return ExecutionStatus.Success;
    }

    function govExecuteMessage(address receiver, bytes calldata message)
        external
        payable
        onlyOwner
    {
        IPMessageReceiverApp(receiver).executeMessage(message);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
