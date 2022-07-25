// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../base-implementations/SCYBase.sol";
import "../../../interfaces/ISAvax.sol";

// BENQI Stake AVAX (sAVAX) -> 0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE

// Exchange rate of sAVAX -> AVAX increases over time, no additional rewards but has a 15day lock-up period with 2 day redemption period.
// Yield Token -> sAVAX (Interest Bearing)

// Additional step if want sAVAX -> deposit into Benqi -> earn more qi Token? (If collateral tokens -> will have additional interest on SAVAX as well - double level of interest) Check with Long/Greg

contract PendleSAvaxSCY is SCYBase {
    address public immutable SAVAX;

    uint256 private constant BASE = 1e18;

    constructor(
        string memory _name,
        string memory _symbol,
        address _sAvax
    ) SCYBase(_name, _symbol, _sAvax) {
        require(_sAvax != address(0), "zero address");
        SAVAX = _sAvax;
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SCYBase-_deposit}
     *
     * The underlying yield token is sAvax. If the base token deposited is native AVAX, the function converts
     * it into sAVAX first. Then the corresponding amount of shares is returned.
     *
     * The exchange rate of sAVAX to shares is 1:1
     */
    function _deposit(address tokenIn, uint256 amountDeposited)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        // Comments: No check for address token IN (need to be implemented in higher level function)
        if (tokenIn == SAVAX) {
            amountSharesOut = amountDeposited;
        } else {
            amountSharesOut = ISAvax(tokenIn).submit{ value: amountDeposited }();
        }
    }

    /**
     * @dev See {SCYBase-_redeem}
     *
     * The shares are redeemed into the same amount of sAVAX. `tokenOut` will only be in sAVAX where exchange rate will be 1:1 to SCY.
     */
    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        require(tokenOut == SAVAX, "only SAVAX allowed.");

        amountTokenOut = amountSharesToRedeem;
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates and updates the exchange rate of shares to underlying asset token
     * @dev It is the exchange rate of sAVAX to AVAX.
     */
    function exchangeRate() public view virtual override returns (uint256 currentRate) {
        return ISAvax(SAVAX).getPooledAvaxByShares(BASE);
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-getBaseTokens}
     */
    function getBaseTokens() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = SAVAX;
        res[1] = NATIVE;
    }

    /**
     * @dev See {ISuperComposableYield-isValidBaseToken}
     */
    function isValidBaseToken(address token) public view virtual override returns (bool) {
        return token == SAVAX || token == NATIVE;
    }

    function assetInfo()
        external
        pure
        returns (
            AssetType assetType,
            address assetAddress,
            uint8 assetDecimals
        )
    {
        return (AssetType.TOKEN, NATIVE, 18);
    }
}
