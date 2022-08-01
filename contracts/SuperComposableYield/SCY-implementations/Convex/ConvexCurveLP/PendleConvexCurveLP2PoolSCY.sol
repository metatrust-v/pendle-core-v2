// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./PendleConvexCurveLPSCY.sol";

contract PendleConvexCurveLP2PoolSCY is PendleConvexCurveLPSCY {
    address public immutable BASEPOOL_TOKEN_1;
    address public immutable BASEPOOL_TOKEN_2;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _pid,
        address _convexBooster,
        address _wrappedLpToken,
        address _cvx,
        address _baseCrvPool,
        address[] memory _currentExtraRewards,
        address[2] memory _basePoolTokens
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
        (int128 index, bool isCrvBasePoolToken) = checkIsCrvBasePoolToken(tokenIn);
        if (isCrvBasePoolToken) {
            ICrvPool Crv2TokenPool = ICrvPool(BASE_CRV_POOL);

            // Append amounts based on index of base Pool token in the curve Pool
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = index == 0 ? amount : 0;
            amounts[1] = index == 1 ? amount : 0;

            // Calculate expected LP Token to receive
            uint256 expectedLpTokenReceive = Crv2TokenPool.calc_token_amount(amounts, true);

            // Add liquidity to curve pool
            uint256 lpAmountReceived = Crv2TokenPool.add_liquidity(
                amounts,
                expectedLpTokenReceive,
                address(this)
            );

            // Deposit Lp Tokens received into Convex Booster
            IBooster(BOOSTER).deposit(PID, lpAmountReceived, true);

            amountSharesOut = lpAmountReceived;
        } else if (tokenIn == CRV_LP_TOKEN) {
            // Directly deposit LP Token into Convex Booster
            IBooster(BOOSTER).deposit(PID, amount, true);
        } else {
            // tokenIn is W_CRV_TOKEN, directly stake in rewards pool
            IRewards(BASE_REWARDS).stakeFor(address(this), amount);
        }
        amountSharesOut = amount;
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
        (int128 index, bool isCrvBasePoolToken) = checkIsCrvBasePoolToken(tokenOut);

        if (tokenOut == W_CRV_LP_TOKEN) {
            // Withdraw W_CRV_LP_TOKEN without claiming rewards
            IRewards(BASE_REWARDS).withdraw(amountSharesToRedeem, false);
            amountTokenOut = amountSharesToRedeem;
        } else {
            uint256 lpTokenPreBalance = _selfBalance(CRV_LP_TOKEN);

            // Withdraw and unwrap from W_CRV_LP_TOKEN to CRV_LP_TOKEN without claiming rewards
            IRewards(BASE_REWARDS).withdrawAndUnwrap(amountSharesToRedeem, false);

            // Determine the exact amount of LP Token received by finding the amount received after withdrawing
            uint256 lpAmountReceived = _selfBalance(CRV_LP_TOKEN) - lpTokenPreBalance;

            if (isCrvBasePoolToken) {
                ICrvPool Crv2TokenPool = ICrvPool(BASE_CRV_POOL);

                // Calculate expected amount of specified token out from Curve pool
                uint256 expectedAmountTokenOut = Crv2TokenPool.calc_withdraw_one_coin(
                    lpAmountReceived,
                    index
                );

                amountTokenOut = Crv2TokenPool.remove_liquidity_one_coin(
                    lpAmountReceived,
                    Math.Int128(Math.Int(expectedAmountTokenOut)),
                    0,
                    msg.sender
                );
            }
        }
    }

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        override
        returns (uint256 amountSharesOut)
    {
        (int128 index, bool isCrvBasePoolToken) = checkIsCrvBasePoolToken(tokenIn);

        if (isCrvBasePoolToken) {
            // Calculate expected amount of LpToken to receive
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = index == 0 ? amountTokenToDeposit : 0;
            amounts[1] = index == 1 ? amountTokenToDeposit : 0;

            uint256 expectedLpTokenReceive = ICrvPool(BASE_CRV_POOL).calc_token_amount(
                amounts,
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
        (int128 index, bool isCrvBasePoolToken) = checkIsCrvBasePoolToken(tokenOut);

        uint256 amountLpTokenToReceive = (amountSharesToRedeem * exchangeRate()) / 1e18;
        if (isCrvBasePoolToken) {
            amountTokenOut = ICrvPool(BASE_CRV_POOL).calc_withdraw_one_coin(
                amountLpTokenToReceive,
                index
            );
        } else {
            // CRV or CVX_CRV token will result in a 1:1 exchangeRate with SCY
            amountTokenOut = amountLpTokenToReceive;
        }
    }

    /**
     * @dev Check if the token address belongs to one of the base token of the curve pool, if so return the 'index' that corresponds with the curvePool contract.
     */
    function checkIsCrvBasePoolToken(address token)
        internal
        view
        returns (int128 index, bool result)
    {
        if (token == BASEPOOL_TOKEN_1) {
            (index, result) = (0, true);
        } else if (token == BASEPOOL_TOKEN_2) {
            (index, result) = (1, true);
        } else {
            (index, result) = (0, false);
        }
    }

    function getTokensIn() public view override returns (address[] memory res) {
        res = new address[](4);
        res[0] = CRV_LP_TOKEN;
        res[1] = W_CRV_LP_TOKEN;
        res[2] = BASEPOOL_TOKEN_1;
        res[3] = BASEPOOL_TOKEN_2;
    }

    function getTokensOut() public view override returns (address[] memory res) {
        res = new address[](4);
        res[0] = CRV_LP_TOKEN;
        res[1] = W_CRV_LP_TOKEN;
        res[2] = BASEPOOL_TOKEN_1;
        res[3] = BASEPOOL_TOKEN_2;
    }

    function isValidTokenIn(address token) public view override returns (bool res) {
        res = (token == CRV_LP_TOKEN ||
            token == W_CRV_LP_TOKEN ||
            token == BASEPOOL_TOKEN_1 ||
            token == BASEPOOL_TOKEN_2);
    }

    function isValidTokenOut(address token) public view override returns (bool res) {
        res = (token == CRV_LP_TOKEN ||
            token == W_CRV_LP_TOKEN ||
            token == BASEPOOL_TOKEN_1 ||
            token == BASEPOOL_TOKEN_2);
    }
}
