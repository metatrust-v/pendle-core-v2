// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./PendleBaseToken.sol";
import "./PendleLiquidYieldToken.sol";
import "./PendleYieldToken.sol";

contract PendleOwnershipToken is PendleBaseToken {
    PendleLiquidYieldToken public immutable LYT;
    PendleYieldToken public YT;

    modifier onlyYT() {
        require(msg.sender == address(YT), "ONLY_YT");
        _;
    }

    constructor(
        PendleLiquidYieldToken _LYT,
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _start,
        uint256 _expiry
    ) PendleBaseToken(_name, _symbol, __decimals, _start, _expiry) {
        LYT = _LYT;
    }

    function initialize(PendleYieldToken _YT) external {
        require(msg.sender == factory, "FORBIDDEN"); // sufficient check
        YT = _YT;
    }

    function burnByYT(address user, uint256 amount) public onlyYT {
        _burn(user, amount);
        emit Burn(user, amount);
    }

    function mintByYT(address user, uint256 amount) public onlyYT {
        // lock mint
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
