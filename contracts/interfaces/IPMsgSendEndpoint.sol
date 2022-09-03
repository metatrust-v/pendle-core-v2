// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

interface IPMsgSendEndpoint {
    function calcFee(
        address dstAddress,
        uint256 dstChainId,
        bytes calldata message
    ) external view returns (uint256);

    function sendMessage(
        address dstAddress,
        uint256 dstChainId,
        bytes calldata message
    ) external payable;
}
