// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPYieldContractFactory.sol";
import "./PermissionsV2.sol";
import "./PendleMarket.sol";

contract PendleMarketFactory is PermissionsV2 {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => EnumerableSet.AddressSet) internal OTmarkets;
    address public immutable vault;
    address public immutable yieldContractFactory;

    constructor(
        address _governanceManager,
        address _vault,
        address _yieldContractFactory
    ) PermissionsV2(_governanceManager) {
        vault = _vault;
        yieldContractFactory = _yieldContractFactory;
    }

    function createNewMarket(
        address OT,
        uint256 feeRateRoot,
        uint256 scalarRoot,
        int256 anchorRoot
    ) external returns (address market) {
        address LYT = IPOwnershipToken(OT).LYT();
        uint256 expiry = IPOwnershipToken(OT).expiry();

        require(
            IPYieldContractFactory(yieldContractFactory).getOT(LYT, expiry) == OT,
            "INVALID_OT"
        );

        market = address(new PendleMarket(OT, vault, feeRateRoot, scalarRoot, anchorRoot));
        OTmarkets[address(OT)].add(market);
    }

    function isValidOTMarket(address market) external view returns (bool) {
        address OT = IPMarket(market).OT();
        return OTmarkets[OT].contains(market);
    }

    // probably should have functions to allow reading from OTmarkets
}
