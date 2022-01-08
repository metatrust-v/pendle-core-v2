// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IPMarket.sol";

contract PendleMarketFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => EnumerableSet.AddressSet) internal OTmarkets;

    function isValidOTMarket(address market) external view returns (bool) {
        address OT = IPMarket(market).OT();
        return OTmarkets[OT].contains(market);
    }
}
