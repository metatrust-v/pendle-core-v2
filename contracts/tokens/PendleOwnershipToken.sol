// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./PendleBaseToken.sol";

contract PendleOwnershipToken is PendleBaseToken {
    address public immutable forge;
    address public immutable underlyingAsset;
    address public immutable underlyingYieldToken;

    modifier onlyForge() {
        require(msg.sender == address(forge), "ONLY_FORGE");
        _;
    }

    constructor(
        address _forge,
        address _underlyingAsset,
        address _underlyingYieldToken,
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _start,
        uint256 _expiry
    ) PendleBaseToken(_name, _symbol, __decimals, _start, _expiry) {
        require(_underlyingAsset != address(0) && _underlyingYieldToken != address(0), "ZERO_ADDRESS");
        require(_forge != address(0), "ZERO_ADDRESS");
        forge = _forge;
        underlyingAsset = _underlyingAsset;
        underlyingYieldToken = _underlyingYieldToken;
    }

    /**
     * @dev Burns OT or XYT tokens from user, reducing the total supply.
     * @param user The address performing the burn.
     * @param amount The amount to be burned.
     **/
    function burn(address user, uint256 amount) public onlyForge {
        _burn(user, amount);
        emit Burn(user, amount);
    }

    /**
     * @dev Mints new OT or XYT tokens for user, increasing the total supply.
     * @param user The address to send the minted tokens.
     * @param amount The amount to be minted.
     **/
    function mint(address user, uint256 amount) public onlyForge {
        _mint(user, amount);
        emit Mint(user, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
    }
}
