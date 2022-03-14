// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
pragma abicoder v2;

import "../../interfaces/IMessageBus.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

abstract contract CrosschainSender is Ownable {
    struct Destination {
        address addr;
        uint256 chainId;
    }

    IMessageBus public messageBus;

    function setCelerMessageBus(IMessageBus _messageBus) external onlyOwner {
        messageBus = _messageBus;
    }

    function _sendDataMultiple(Destination[] memory destinations, bytes memory data) internal {
        for (uint256 i = 0; i < destinations.length; ++i) {
            _sendDataSingle(destinations[i], data);
        }
    }

    function _sendDataSingle(Destination memory dest, bytes memory data) internal {
        uint256 fee = messageBus.calcFee(data);
        messageBus.sendMessage{ value: fee }(dest.addr, dest.chainId, data);
    }
}
