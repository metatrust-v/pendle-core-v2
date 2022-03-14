// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.9;
pragma abicoder v2;

import "./EpochController.sol";
import "./vePendle/vePendle.sol";
import "./GaugeTypeController/GaugeTypeControllerMainchain.sol";
import "../CrosschainContracts/CrosschainSender.sol";

contract VotingController is CrosschainSender, EpochController {
    using LineHelper for Line;

    struct UserGaugeVote {
        Line votingLine;
        uint256 votingWeight;
    }

    uint256 public constant VOTING_PRECISION = 1_000_000_000;

    vePendle public immutable votingPendle;
    uint256 public immutable mainchainId;
    address public gaugeControllerMainchain;

    mapping(address => uint256) public userVotedWeight;
    mapping(address => mapping(address => UserGaugeVote)) public userGaugeVotes;

    mapping(address => Line) public gaugeLines;
    mapping(address => uint256) public lastGaugeEpoch;
    mapping(address => mapping(uint256 => uint256)) public expiredVotes;

    Destination[] public chains;
    mapping(uint256 => address[]) public gaugeInChains;

    constructor(
        vePendle _votingPendle,
        uint256 _mainchainId,
        uint256 _startTime
    ) EpochController(_startTime) {
        votingPendle = _votingPendle;
        mainchainId = _mainchainId;
    }

    receive() external payable {}

    /**
        @dev this function is implied to be call every epoch (at the end maybe)
     */
    function broadcastVotingResults() external payable {
        uint256 accumulatingFees = 0;
        uint256 epochEnding = getEpochEndingTimestamp(getEpochId(block.timestamp));
        for (uint256 i = 0; i < chains.length; ++i) {
            Destination memory dest = chains[i];
            uint256 chainId = dest.chainId;
            address[] memory gauges = gaugeInChains[chainId];
            uint256[] memory votes = new uint256[](gauges.length);

            for (uint256 j = 0; j < gauges.length; ++j) {
                address gauge = gauges[j];
                votes[j] = gaugeLines[gauge].getValueAt(epochEnding);
            }

            bytes memory data = abi.encode(gauges, votes);
            accumulatingFees += messageBus.calcFee(data);
            require(msg.value >= accumulatingFees, "NOT_ENOUGH_FEE");

            if (chainId != mainchainId) {
                _sendDataSingle(dest, data);
            } else {
                GaugeTypeControllerMainchain(gaugeControllerMainchain).setVotingResults(
                    gauges,
                    votes
                );
            }
        }
    }

    function updateGauge(address gauge) public returns (Line memory gaugeVotes) {
        uint256 currentEpoch = getEpochId(block.timestamp);
        gaugeVotes = gaugeLines[gauge];
        for (uint256 epoch = lastGaugeEpoch[gauge]; epoch < currentEpoch; ++epoch) {
            uint256 endTimestamp = getEpochEndingTimestamp(epoch);
            uint256 expiredSlope = expiredVotes[gauge][endTimestamp];
            gaugeVotes = gaugeVotes.sub(Line(expiredSlope, expiredSlope * endTimestamp));
        }
        lastGaugeEpoch[gauge] = currentEpoch - 1;
        gaugeLines[gauge] = gaugeVotes;
    }

    function voteForGauge(
        address user,
        address gauge,
        uint256 newWeight
    ) external {
        require(votingPendle.balanceOf(user) > 0, "ZERO_VEPENDLE");

        Line memory gaugeVotes = updateGauge(gauge);
        UserGaugeVote memory oldVote = userGaugeVotes[user][gauge];
        if (oldVote.votingLine.getCurrentBalance() > 0) {
            gaugeVotes = gaugeVotes.sub(oldVote.votingLine);
            expiredVotes[gauge][oldVote.votingLine.getExpiry()] -= oldVote.votingLine.slope;
        }

        userVotedWeight[gauge] = userVotedWeight[gauge] - oldVote.votingWeight + newWeight;
        require(userVotedWeight[gauge] <= VOTING_PRECISION, "VOTING_WEIGHT_EXCEED");

        (uint256 slope, uint256 bias) = votingPendle.userLock(user);
        uint256 expiry = bias / slope;
        uint256 partialSlope = (slope * newWeight) / VOTING_PRECISION;
        Line memory newVote = Line(partialSlope, partialSlope * expiry);

        userGaugeVotes[user][gauge] = UserGaugeVote(newVote, newWeight);
        gaugeLines[gauge] = gaugeVotes.add(newVote);
        expiredVotes[gauge][expiry] += newVote.slope;
    }

    function setGaugeControllerMainchain(address newController) external onlyOwner {
        gaugeControllerMainchain = newController;
    }

    function supportNewChain(uint256 chainId, address controller) external onlyOwner {
        for (uint256 i = 0; i < chains.length; ++i) {
            if (chains[i].chainId == chainId) {
                chains[i].addr = controller;
                return;
            }
        }
        chains.push(Destination(controller, chainId));
    }

    function addNewGauge(uint256 chainId, address gauge) external onlyOwner {
        bool validChainId = false;
        for (uint256 i = 0; i < chains.length; ++i) {
            if (chains[i].chainId == chainId) {
                validChainId = true;
                break;
            }
        }
        require(validChainId, "UNSUPPORTED_CHAIN");
        gaugeInChains[chainId].push(gauge);
    }
}
