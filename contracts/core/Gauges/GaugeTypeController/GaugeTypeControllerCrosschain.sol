// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
pragma abicoder v2;

import "./GaugeTypeControllerAbstract.sol";
import "../../CrosschainContracts/CrosschainReceiver.sol";

contract GaugeTypeControllerCrosschain is GaugeTypeControllerAbstract, CrosschainReceiver {
    constructor(
        MessageOrigin memory _votingController,
        IERC20 _pendle,
        uint256 _startTime
    ) GaugeTypeControllerAbstract(_pendle, _startTime) {
        messageOrigin = _votingController;
    }

    function _afterReceiveData(bytes memory data) internal override {
        (address[] memory gauges, uint256[] memory votes) = abi.decode(
            data,
            (address[], uint256[])
        );
        _setVotingResults(gauges, votes);
    }
}
