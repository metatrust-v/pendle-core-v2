// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
pragma abicoder v2;

import "../../interfaces/IMessageReceiverApp.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

abstract contract CrosschainReceiver is Ownable, IMessageReceiverApp {
    struct MessageOrigin {
        address addr;
        uint64 chainId;
    }

    MessageOrigin public messageOrigin;
    mapping(address => bool) public whitelistedMessageBus;

    function setMessageOrigin(MessageOrigin calldata newMessageOrigin) external onlyOwner {
        messageOrigin = newMessageOrigin;
    }

    function setMessageBusWhitelist(address messageBus, bool state) external onlyOwner {
        whitelistedMessageBus[messageBus] = state;
    }

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message
    ) external payable override returns (bool) {
        require(whitelistedMessageBus[msg.sender], "NOT_WHITELISTED_MESSAGE_BUS");
        if (_sender != messageOrigin.addr || _srcChainId != messageOrigin.chainId) {
            return false;
        }
        _afterReceiveData(_message);
        return true;
    }

    function _afterReceiveData(bytes memory data) internal virtual;
}
