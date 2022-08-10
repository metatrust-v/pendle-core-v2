pragma solidity 0.8.15;

import "./QiTokenSaleDistributorProxyStorage.sol";

contract QiTokenSaleDistributorStorage is QiTokenSaleDistributorProxyStorage {
    // Token release interval in seconds
    uint256 public constant releasePeriodLength = 2628000; // = 60 * 60 * 24 * 365 / 12 = 1 month

    // Block time when the purchased tokens were initially released for claiming
    uint256 public constant vestingScheduleEpoch = 1629356400;

    address public dataAdmin;

    address public qiContractAddress;

    // Number of release periods in the vesting schedule; i.e.,
    // releasePeriods * releasePeriodLength = vesting period length
    // address => purchase round => release periods
    mapping(address => mapping(uint256 => uint256)) public releasePeriods;

    // The percentage of tokens released on vesting schedule start (0-100)
    // address => purchase round => initial release percentage
    mapping(address => mapping(uint256 => uint256)) public initialReleasePercentages;

    // Total number of purchased QI tokens by user
    // address => purchase round => purchased tokens
    mapping(address => mapping(uint256 => uint256)) public purchasedTokens;

    // Total number of claimed QI tokens by user
    // address => purchase round => claimed tokens
    mapping(address => mapping(uint256 => uint256)) public claimedTokens;

    // Number of purchase rounds completed by the user
    mapping(address => uint256) public completedPurchaseRounds;
}
