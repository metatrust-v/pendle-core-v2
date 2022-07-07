// SPDX-License-Identifier: GPL-3.0-or-later
/*
 * MIT License
 * ===========
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 */

pragma solidity 0.8.15;

import "../../interfaces/IPYieldContractFactory.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../../libraries/helpers/ExpiryUtilsLib.sol";
import "../../libraries/helpers/SSTORE2Deployer.sol";

import "../../periphery/PermissionsV2Upg.sol";

import "./PendlePrincipalToken.sol";
import "./PendleYieldToken.sol";

/// @dev If this contract is ever made upgradeable, please pay attention to the numContractDeployed variable
contract PendleYieldContractFactory is PermissionsV2Upg, Initializable, IPYieldContractFactory {
    using ExpiryUtils for string;

    string private constant PT_PREFIX = "PT";
    string private constant YT_PREFIX = "YT";

    address public pendleYtCreationCodePointer;

    uint256 public expiryDivisor;
    uint256 public interestFeeRate;
    address public treasury;

    /// number of contracts that have been deployed from this address
    /// must be increased everytime a new contract is deployed
    uint256 public numContractDeployed;

    // SCY => expiry => address
    mapping(address => mapping(uint256 => address)) public getPT;
    mapping(address => mapping(uint256 => address)) public getYT;
    mapping(address => bool) public isPT;
    mapping(address => bool) public isYT;

    constructor(
        uint256 _expiryDivisor,
        uint256 _interestFeeRate,
        address _treasury,
        address _governanceManager
    ) PermissionsV2Upg(_governanceManager) {
        setExpiryDivisor(_expiryDivisor);
        setInterestFeeRate(_interestFeeRate);
        setTreasury(_treasury);
        numContractDeployed++;
    }

    function initialize(bytes memory _pendleYtCreationCode) external initializer {
        pendleYtCreationCodePointer = SSTORE2Deployer.setCreationCode(_pendleYtCreationCode);
    }

    /**
     * @notice Create a pair of (PT, YT) from any SCY and valid expiry. Anyone can create a yield contract
     */
    function createYieldContract(address SCY, uint256 expiry)
        external
        returns (address PT, address YT)
    {
        require(expiry > block.timestamp, "expiry must be in the future");

        require(expiry % expiryDivisor == 0, "must be multiple of divisor");

        require(getPT[SCY][expiry] == address(0), "PT already existed");

        ISuperComposableYield _SCY = ISuperComposableYield(SCY);

        (, , uint8 assetDecimals) = _SCY.assetInfo();

        // no need salt since PT (and also YT) existence has been checked before hand
        PT = SSTORE2Deployer.create2(
            type(PendlePrincipalToken).creationCode,
            bytes32(0),
            abi.encode(
                SCY,
                PT_PREFIX.concat(_SCY.name(), expiry, " "),
                PT_PREFIX.concat(_SCY.symbol(), expiry, "-"),
                assetDecimals,
                expiry
            )
        );

        YT = SSTORE2Deployer.create2(
            pendleYtCreationCodePointer,
            bytes32(0),
            abi.encode(
                SCY,
                PT,
                YT_PREFIX.concat(_SCY.name(), expiry, " "),
                YT_PREFIX.concat(_SCY.symbol(), expiry, "-"),
                assetDecimals,
                expiry
            )
        );

        IPPrincipalToken(PT).initialize(YT);

        getPT[SCY][expiry] = PT;
        getYT[SCY][expiry] = YT;
        isPT[PT] = true;
        isYT[YT] = true;

        emit CreateYieldContract(SCY, PT, YT, expiry);
    }

    function setExpiryDivisor(uint256 newExpiryDivisor) public onlyGovernance {
        require(newExpiryDivisor != 0, "zero value");
        expiryDivisor = newExpiryDivisor;
        emit SetExpiryDivisor(newExpiryDivisor);
    }

    function setInterestFeeRate(uint256 newInterestFeeRate) public onlyGovernance {
        interestFeeRate = newInterestFeeRate;
        emit SetInterestFeeRate(newInterestFeeRate);
    }

    function setTreasury(address newTreasury) public onlyGovernance {
        require(newTreasury != address(0), "zero address");
        treasury = newTreasury;
        emit SetTreasury(newTreasury);
    }
}
