// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";

abstract contract PendleBaseToken is ERC20 {
    uint256 public immutable timeCreated;
    uint256 public immutable expiry;
    uint8 private immutable _decimals;
    address public immutable factory;

    event Burn(address indexed user, uint256 amount);

    event Mint(address indexed user, uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _expiry
    ) ERC20(_name, _symbol) {
        _decimals = __decimals;
        timeCreated = block.timestamp;
        expiry = _expiry;
        factory = msg.sender;
        require(expiry < block.timestamp, "INVALID_EXPIRY");
    }
}
