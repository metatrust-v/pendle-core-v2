// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
pragma abicoder v2;
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "./vePendleToken.sol";
import "../../CrosschainContracts/CrosschainReceiver.sol";

contract vePendleCrosschain is vePendleToken, CrosschainReceiver {
    IERC20 public immutable pendle;

    constructor(IERC20 _pendle, uint256 _startTime) EpochController(_startTime) {
        pendle = _pendle;
    }

    function _afterReceiveData(bytes memory data) internal override {
        (address user, uint256 slope, uint256 bias) = abi.decode(data, (address, uint256, uint256));
        _setUserBalance(user, Line(slope, bias));
    }
}
