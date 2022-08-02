// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./PendleConvexCurveLPSCY.sol";

contract PendleConvexCurveLP4PoolSCY is PendleConvexCurveLPSCY {
    address public immutable BASEPOOL_TOKEN_1;
    address public immutable BASEPOOL_TOKEN_2;
    address public immutable BASEPOOL_TOKEN_3;
    address public immutable BASEPOOL_TOKEN_4;
    uint256 public constant BASEPOOL_TOKEN_LENGTH = 4;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _pid,
        address _convexBooster,
        address _wrappedLpToken,
        address _cvx,
        address _baseCrvPool,
        address[] memory _currentExtraRewards,
        address[4] memory _basePoolTokens
    )
        PendleConvexCurveLPSCY(
            _name,
            _symbol,
            _pid,
            _convexBooster,
            _wrappedLpToken,
            _cvx,
            _baseCrvPool,
            _currentExtraRewards
        )
    {
        BASEPOOL_TOKEN_1 = _basePoolTokens[0];
        BASEPOOL_TOKEN_2 = _basePoolTokens[1];
        BASEPOOL_TOKEN_3 = _basePoolTokens[2];
        BASEPOOL_TOKEN_4 = _basePoolTokens[3];
    }

    /**
     * @dev See {SCYBase-_deposit}
     *
     * The underlying yield token is CRV_LP_TOKEN.
     *
     * Tokens accepted for deposit are CRV_LP_TOKEN, W_CRV_LP_TOKEN, or any of the base tokens of the curve pool.
     *
     * If any of the base pool tokens are deposited, it will first add liquidity to the curve pool and mint CRV_LP_TOKEN, which will then be deposited into convexCurveLP Pool which will automatically swap for W_CRV_LP_TOKEN and stake.
     *
     *Apart from accepting CRV_LP_TOKEN, Wrapped CRV_LP_TOKEN for staking in baseRewardsPool contract can be accepted also. Then the corresponding amount of shares is returned.
     *
     * The exchange rate of CRV_LP_TOKEN (or wrapped CRV_LP_TOKEN) to SCY is based on existing liquidity
     */
    function _deposit(address tokenIn, uint256 amount)
        internal
        override
        returns (uint256 amountSharesOut)
    {
        if (isCrvBaseToken(tokenIn)) {
            // Check if 'tokenIn' is a CrvBaseToken
            ICrvPool Crv4TokenPool = ICrvPool(BASE_CRV_POOL);

            // Append amounts based on index of base Pool token in the curve Pool
            uint256[] memory amountsToDeposit = _assignDepositAmountToCrvBaseTokenIndex(
                tokenIn,
                amount
            );

            // Calculate expected LP Token to receive
            uint256 expectedLpTokenReceive = Crv4TokenPool.calc_token_amount(
                amountsToDeposit,
                true
            );

            // Add liquidity to curve pool
            uint256 lpAmountReceived = Crv4TokenPool.add_liquidity(
                amountsToDeposit,
                expectedLpTokenReceive,
                address(this)
            );

            // Deposit LP Token received into Convex Booster
            IBooster(BOOSTER).deposit(PID, lpAmountReceived, true);

            amountSharesOut = (lpAmountReceived * 1e18) / exchangeRate();
        } else if (tokenIn == CRV_LP_TOKEN) {
            // Directly deposit LP Token into Convex Booster
            IBooster(BOOSTER).deposit(PID, amount, true);
        } else {
            // tokenIn is W_CRV_TOKEN, directly stake in rewards pool
            IRewards(BASE_REWARDS).stakeFor(address(this), amount);
        }
        // If 'tokenIn' is CRV_LP_TOKEN or W_CRV_LP_TOKEN, calculate shares LP token amount is entitled to
        amountSharesOut = (amount * 1e18) / exchangeRate();
    }

    /**
     * @dev See {SCYBase-_redeem}
     *
     * The shares are redeemed into the same amount of CRV_LP_TOKEN or W_CRV_LP_TOKEN .
     *
     * Tokens eligible for withdrawal are CRV_LP_TOKEN, W_CRV_LP_TOKEN or any of the curve pool base tokens.
     *
     *If CRV_LP_TOKEN or W_CRV_LP_TOKEN is specified as the withdrawal token, amountSharesToRedeem will always correspond amountTokenOut.
     *
     * If any of the base curve pool tokens is specified as 'tokenOut', it will redeem the corresponding liquidity the LP token represents via the prevailing exchange rate.
     */
    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == W_CRV_LP_TOKEN) {
            // If 'tokenOut' is wrapped CRV_LP_TOKEN, Withdraw W_CRV_LP_TOKEN without claiming rewards
            IRewards(BASE_REWARDS).withdraw(amountSharesToRedeem, false);
            amountTokenOut = amountSharesToRedeem;
        } else {
            //'tokenOut' is CRV_LP_TOKEN or one of the Curve Pool Base Tokens
            uint256 lpTokenPreBalance = _selfBalance(CRV_LP_TOKEN);

            // Withdraw and unwrap from W_CRV_LP_TOKEN to CRV_LP_TOKEN without claiming rewards
            IRewards(BASE_REWARDS).withdrawAndUnwrap(amountSharesToRedeem, false);

            // Determine the exact amount of LP Token received by finding the amount received after withdrawing
            uint256 lpAmountReceived = _selfBalance(CRV_LP_TOKEN) - lpTokenPreBalance;

            if (isCrvBaseToken(tokenOut)) {
                ICrvPool Crv4TokenPool = ICrvPool(BASE_CRV_POOL);

                // Calculate expected amount of specified token out from Curve pool
                uint256 expectedAmountTokenOut = Crv4TokenPool.calc_withdraw_one_coin(
                    lpAmountReceived,
                    Math.Int128(Math.Int(_getIndexOfCrvBaseToken(tokenOut)))
                );

                amountTokenOut = Crv4TokenPool.remove_liquidity_one_coin(
                    lpAmountReceived,
                    Math.Int128(Math.Int(expectedAmountTokenOut)),
                    0,
                    msg.sender
                );
            } else {
                // If 'tokenOut' is CRV_LP_TOKEN
                amountTokenOut = lpAmountReceived;
            }
        }
    }

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        override
        returns (uint256 amountSharesOut)
    {
        if (isCrvBaseToken(tokenIn)) {
            // Calculate expected amount of LpToken to receive
            uint256[] memory amountsToDeposit = _assignDepositAmountToCrvBaseTokenIndex(
                tokenIn,
                amountTokenToDeposit
            );

            uint256 expectedLpTokenReceive = ICrvPool(BASE_CRV_POOL).calc_token_amount(
                amountsToDeposit,
                true
            );

            // Using expected amount of LP tokens to receive, calculated amount of shares (SCY) base on exchange rate
            amountSharesOut = (expectedLpTokenReceive * 1e18) / exchangeRate();
        } else {
            // CRV or CVX_CRV token will result in a 1:1 exchangeRate with SCY
            amountSharesOut = (amountTokenToDeposit * 1e18) / exchangeRate();
        }
    }

    function _previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        view
        override
        returns (uint256 amountTokenOut)
    {
        uint256 amountLpTokenToReceive = (amountSharesToRedeem * exchangeRate()) / 1e18;

        if (isCrvBaseToken(tokenOut)) {
            // If 'tokenOut' is a CrvBaseToken, withdraw liquidity from curvePool to return the base token back to user.
            amountTokenOut = ICrvPool(BASE_CRV_POOL).calc_withdraw_one_coin(
                amountLpTokenToReceive,
                Math.Int128(Math.Int(_getIndexOfCrvBaseToken(tokenOut)))
            );
        } else {
            // CRV or CVX_CRV token will result in a 1:1 exchangeRate with SCY
            amountTokenOut = amountLpTokenToReceive;
        }
    }

    function getTokensIn() public view override returns (address[] memory res) {
        res = new address[](6);
        res[0] = CRV_LP_TOKEN;
        res[1] = W_CRV_LP_TOKEN;
        res[2] = BASEPOOL_TOKEN_1;
        res[3] = BASEPOOL_TOKEN_2;
        res[4] = BASEPOOL_TOKEN_3;
        res[5] = BASEPOOL_TOKEN_4;
    }

    function getTokensOut() public view override returns (address[] memory res) {
        res = new address[](6);
        res[0] = CRV_LP_TOKEN;
        res[1] = W_CRV_LP_TOKEN;
        res[2] = BASEPOOL_TOKEN_1;
        res[3] = BASEPOOL_TOKEN_2;
        res[4] = BASEPOOL_TOKEN_3;
        res[5] = BASEPOOL_TOKEN_4;
    }

    function isValidTokenIn(address token) public view override returns (bool res) {
        res = (token == CRV_LP_TOKEN ||
            token == W_CRV_LP_TOKEN ||
            token == BASEPOOL_TOKEN_1 ||
            token == BASEPOOL_TOKEN_2 ||
            token == BASEPOOL_TOKEN_3 ||
            token == BASEPOOL_TOKEN_4);
    }

    function isValidTokenOut(address token) public view override returns (bool res) {
        res = (token == CRV_LP_TOKEN ||
            token == W_CRV_LP_TOKEN ||
            token == BASEPOOL_TOKEN_1 ||
            token == BASEPOOL_TOKEN_2 ||
            token == BASEPOOL_TOKEN_3 ||
            token == BASEPOOL_TOKEN_4);
    }

    /**
     * @dev To be overriden by the pool type variation contract and return the respective index based on the registered Index of the Curve Base Token.
     *
     * This function will only be called once the token has been checked that it is one of the Curve Base Pool Tokens.
     */
    function _getIndexOfCrvBaseToken(address crvBaseToken)
        internal
        view
        override
        returns (uint256 index)
    {
        if (crvBaseToken == BASEPOOL_TOKEN_1) {
            index = 0;
        } else if (crvBaseToken == BASEPOOL_TOKEN_2) {
            index = 1;
        } else if (crvBaseToken == BASEPOOL_TOKEN_3) {
            index = 2;
        } else {
            index = 3;
        }
    }

    /**
     * @dev To be overriden by the pool type variation contract and return the true of token belongs to one of the registered Curve Base Pool Tokens, else return false.
     */
    function isCrvBaseToken(address token) public view override returns (bool res) {
        return (token == BASEPOOL_TOKEN_1 ||
            token == BASEPOOL_TOKEN_2 ||
            token == BASEPOOL_TOKEN_3 ||
            token == BASEPOOL_TOKEN_4);
    }

    /**
     * @dev To be overriden by the pool type variation contract and return an array length that corresponds to the size of the curve pool variation (i.e. length of 2 if base pool size of 2).
     *
     * CrvTokenPool Contract requires an array with each respective index representing the registered index of the curveBaseToken inside the CurvePool to calculate the expected Amount of LP Token to receive upon adding liquidity and this is required before calling 'add_liquidity' to the curve Pool.
     *
     * Given that only 1 token can only be deposited in '_deposit()' function, this function will be called to assign the 'amount' to deposit to the respective index should the token specified be one of the CurveBasePoolToken.
     */
    function _assignDepositAmountToCrvBaseTokenIndex(address crvBaseToken, uint256 amountDeposited)
        internal
        view
        override
        returns (uint256[] memory res)
    {
        res = new uint256[](BASEPOOL_TOKEN_LENGTH);
        res[_getIndexOfCrvBaseToken(crvBaseToken)] = amountDeposited;
    }
}
