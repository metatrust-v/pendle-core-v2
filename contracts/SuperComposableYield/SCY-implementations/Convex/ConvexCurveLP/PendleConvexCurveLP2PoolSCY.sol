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

    function _deposit(address tokenIn, uint256 amount)
        internal
        override
        returns (uint256 amountSharesOut)
    {
        (int128 index, bool isCrvBasePoolToken) = checkIsCrvBasePoolToken(tokenIn);
        if (isCrvBasePoolToken) {
            ICrvPool Crv2TokenPool = ICrvPool(BASE_CRV_POOL);

            uint256[] memory amounts = new uint256[](2);
            amounts[0] = index == 0 ? amount : 0;
            amounts[1] = index == 1 ? amount : 0;

            uint256 expectedAmount = Crv2TokenPool.calc_token_amount(amounts, true);

            uint256 lpAmountReceived = Crv2TokenPool.add_liquidity(
                amounts,
                expectedAmount,
                address(this)
            );

            IBooster(BOOSTER).deposit(PID, lpAmountReceived, true);

            amountSharesOut = lpAmountReceived;
        } else if (tokenIn == CRV_LP_TOKEN) {
            IBooster(BOOSTER).deposit(PID, amount, true);
        } else {
            IRewards(BASE_REWARDS).stakeFor(address(this), amount);
        }
        amountSharesOut = amount;
    }

    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        override
        returns (uint256 amountTokenOut)
    {
        (int128 index, bool isCrvBasePoolToken) = checkIsCrvBasePoolToken(tokenOut);

        if (tokenOut != W_CRV_LP_TOKEN) {
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
        } else {
            // Withdraw W_CRV_LP_TOKEN without claiming rewards
            IRewards(BASE_REWARDS).withdraw(amountSharesToRedeem, false);
        }
        amountTokenOut = amountSharesToRedeem;
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

            uint256 expectedAmount = ICrvPool(BASE_CRV_POOL).calc_token_amount(amounts, true);

            // Using expected amount of LP tokens to receive, calculated amount of shares (SCY) base on exchange rate
            amountSharesOut = (expectedAmount * 1e18) / exchangeRate();
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
