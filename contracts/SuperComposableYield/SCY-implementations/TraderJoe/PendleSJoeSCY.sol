// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../base-implementations/SCYBaseWithRewards.sol";
import "../../../interfaces/ISJoe.sol";

/*
sJOE Staking
sJOE Staking is a highly accessible Staking option. Users can Stake into sJOE and unstake from sJOE at any time. There is however a deposit fee mechanism to prevent over-saturation.

Deposit Fee
Staking into sJOE may come with a fee
The fee can scale up to 3% Max, depending on the number of JOEs already Staked
The 3% Fee is taken from the JOEs that you deposit into the sJOE Pool
Currently any deposit fee taken will be sent to the Treasury 


Yield Generating Mechanism - Stake JOE into SJOE Contract

Asset - JOE

Shares - Shares (in contract *take note of deduction of fees after depositing)

Exchange Rate - Increases with sJOE rewards


*/
// sJOE -> Staking contract that accepts JOE and yields USDC as the ONLY reward token
// sJOE Contract Address on Avalanche -> 0x1a731B2299E22FbAC282E7094EdA41046343Cb51

// JOE Contract Address on Avalanche -> 0x6e84a6216ea6dacc71ee8e6b0a5b7322eebc0fdd

contract PendleSJoeSCY is SCYBaseWithRewards {
    using SafeERC20 for IERC20;

    address public immutable SJOE;
    address public immutable JOE;
    address public immutable USDC;

    constructor(
        string memory _name,
        string memory _symbol,
        address _sJOE,
        address _JOE,
        address _USDC
    ) SCYBaseWithRewards(_name, _symbol, _JOE) {
        require(_sJOE != address(0), "zero address");
         require(_JOE != address(0), "zero address");
         require(_USDC != address(0), "zero address");
        SJOE = _sJOE;
        JOE = _JOE;
        USDC = _USDC;

        _safeApprove(JOE, SJOE, type(uint256).max);
    }

        /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {SCYBase-_deposit}
     *
     * The underlying yield token is JOE (Since the amount of rewards is based on how much staked JOE inside sJOE contract). Only the base token JOE should be accepted. Then the corresponding amount of shares is returned.
     *
     * The exchange rate of JOE to shares is 1:1

    * Each time deposit() is called, any pending rewards will be sent back to the SCY by default.
     */
      function _deposit(address tokenIn, uint256 amount)
        internal
        override
        returns (uint256 amountSharesOut)
    {
      // tokenIn is underlying == yield token (JOE)
      require(tokenIn == JOE, "invalid yield token");

      uint256 preBalanceSJoe = ISJoe(SJOE).internalJoeBalance();

      ISJoe(SJOE).deposit(amount);

        // Depositing JOE will incur deposit fee, hence amountSharesOut has to be calculated like this for accurate amount of SCY exchanged.
      amountSharesOut = ISJoe(SJOE).internalJoeBalance() - preBalanceSJoe;


    }


       /**
     * @dev See {SCYBase-_redeem}
     *
     * The shares are redeemed into the same amount of JOE Tokens. Hence `tokenOut` will only be the underlying asset (JOE) in this case. Since there will NOT be any withdrawal fee from sJOE, amountSharesToRedeem will always correspond amountTokenOut.
     */
    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        override
        returns (uint256 amountTokenOut)
    {
    ISJoe(SJOE).withdraw(amountSharesToRedeem);
    amountTokenOut = amountSharesToRedeem;
    }


     /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exchange rate for JOE to SCY is 1:1
     * @dev It is the exchange rate of Shares in sJOE to its underlying asset (JOE)
     */
    function exchangeRate() public view override returns (uint256) {
        return SCYUtils.ONE;
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-getRewardTokens}
     */
    function _getRewardTokens() internal view override returns (address[] memory res) {
        res = new address[](1);
        res[0] = USDC;
   
    }

    function _redeemExternalReward() internal override {
        // Since sJOE contract has no 'claimRewards' function, call withdraw() with a 0 amount to claim the rewards - Same as how sJOE pool is doing for their frontend.
         ISJoe(SJOE).withdraw(0);
    }

    /*///////////////////////////////////////////////////////////////
                    MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-getBaseTokens}
     */
    function getBaseTokens() public view override returns (address[] memory res) {
        res = new address[](1);
        res[0] = JOE;
    }

    /**
     * @dev See {ISuperComposableYield-isValidBaseToken}
     */
    function isValidBaseToken(address token) public view override returns (bool res) {
        res = ( token == JOE);
    }

    function assetInfo()
        external
        view
        returns (
            AssetType assetType,
            address assetAddress,
            uint8 assetDecimals
        )
    {
        return (
            AssetType.TOKEN,
            JOE,
        IERC20Metadata(JOE).decimals()
        );
    }
}

