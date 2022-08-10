pragma solidity 0.8.15;

import "./BENQI-Smart-Contracts/Chainlink/AggregatorV2V3Interface.sol";

contract MockBenqiFeed is AggregatorV2V3Interface {
    int256 public price;

    constructor(int256 _price) {
        price = _price;
    }

    function latestAnswer() external view returns (int256) {
        return price;
    }

    function latestTimestamp() external view returns (uint256) {
        return block.timestamp;
    }

    function latestRound() external view returns (uint256) {
        return 1;
    }

    function getAnswer(uint256 roundId) external view returns (int256) {
        return 0;
    }

    function getTimestamp(uint256 roundId) external view returns (uint256) {
        return 0;
    }

    //
    // V3 Interface:
    //
    function decimals() external view returns (uint8) {
        return 8;
    }

    function description() external view returns (string memory) {
        return "";
    }

    function version() external view returns (uint256) {
        return 1;
    }

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, 0, 0, 0, 0);
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, 0, 0, 0, 0);
    }
}
