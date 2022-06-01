// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./PendleGaugeController.sol";
import "../CelerAbstracts/CelerReceiver.sol";

// solhint-disable no-empty-blocks
contract PendleGaugeControllerSidechain is PendleGaugeController, CelerReceiver {

    constructor(
        address _pendle,
        address _marketFactory,
        address _governanceManager
    ) PendleGaugeController(_pendle, _marketFactory) CelerReceiver(_governanceManager) {}

    function _executeMessage(bytes memory message) internal virtual override {
        (uint128 timestamp, address[] memory markets, uint128[] memory incentives) = abi.decode(
            message,
            (uint128, address[], uint128[])
        );
        _receiveVotingResults(timestamp, markets, incentives);
    }
}
