// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./ConvexCurveLP/PendleConvexCurveLP2PoolSCY.sol";
import "./Pendle3CrvHelper.sol";
import "../../../libraries/helpers/ArrayLib.sol";

contract Pendle3CrvTokenSCY is PendleConvexCurveLP2PoolSCY {
    using ArrayLib for address[];

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _pid,
        address _convexBooster,
        address _crvLpToken,
        address _cvx,
        address _baseCrvPool,
        address[] memory _currentExtraRewards,
        address[] memory _basePoolTokens
    )
        PendleConvexCurveLP2PoolSCY(
            _name,
            _symbol,
            _pid,
            _convexBooster,
            _crvLpToken,
            _cvx,
            _baseCrvPool,
            _currentExtraRewards,
            _basePoolTokens
        )
    {
        require(_basePoolTokens.contains(Pendle3CrvHelper.TOKEN), "3Crv Pool address not found");

        _safeApproveInf(Pendle3CrvHelper.DAI, Pendle3CrvHelper.POOL);
        _safeApproveInf(Pendle3CrvHelper.USDC, Pendle3CrvHelper.POOL);
        _safeApproveInf(Pendle3CrvHelper.USDT, Pendle3CrvHelper.POOL);
    }

    function _deposit(address tokenIn, uint256 amount)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (Pendle3CrvHelper.is3CrvToken(tokenIn)) {
            uint256 amountLp = Pendle3CrvHelper.deposit3Crv(tokenIn, amount);
            return super._deposit(Pendle3CrvHelper.TOKEN, amountLp);
        } else {
            return super._deposit(tokenIn, amount);
        }
    }

    function _redeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        if (Pendle3CrvHelper.is3CrvToken(tokenOut)) {
            uint256 amountLp = super._redeem(Pendle3CrvHelper.TOKEN, amountSharesToRedeem);
            return Pendle3CrvHelper.redeem3Crv(tokenOut, amountLp);
        } else {
            return super._redeem(tokenOut, amountSharesToRedeem);
        }
    }

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        if (Pendle3CrvHelper.is3CrvToken(tokenIn)) {
            uint256 amountLp = Pendle3CrvHelper.preview3CrvDeposit(tokenIn, amountTokenToDeposit);
            return super._previewDeposit(Pendle3CrvHelper.TOKEN, amountLp);
        } else {
            return super._previewDeposit(tokenIn, amountTokenToDeposit);
        }
    }

    function _previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        if (Pendle3CrvHelper.is3CrvToken(tokenOut)) {
            uint256 amountLp = super._previewRedeem(Pendle3CrvHelper.TOKEN, amountSharesToRedeem);
            return Pendle3CrvHelper.preview3CrvRedeem(tokenOut, amountLp);
        } else {
            return super._previewRedeem(tokenOut, amountSharesToRedeem);
        }
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](7);
        res[0] = CRV_LP_TOKEN;
        res[1] = BASEPOOL_TOKEN_1;
        res[2] = BASEPOOL_TOKEN_2;
        res[3] = Pendle3CrvHelper.DAI;
        res[4] = Pendle3CrvHelper.USDC;
        res[5] = Pendle3CrvHelper.USDT;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](7);
        res[0] = CRV_LP_TOKEN;
        res[1] = BASEPOOL_TOKEN_1;
        res[2] = BASEPOOL_TOKEN_2;
        res[3] = Pendle3CrvHelper.DAI;
        res[4] = Pendle3CrvHelper.USDC;
        res[5] = Pendle3CrvHelper.USDT;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool res) {
        res = (token == CRV_LP_TOKEN ||
            token == BASEPOOL_TOKEN_1 ||
            token == BASEPOOL_TOKEN_2 ||
            Pendle3CrvHelper.is3CrvToken(token));
    }

    function isValidTokenOut(address token) public view override returns (bool res) {
        res = (token == CRV_LP_TOKEN ||
            token == BASEPOOL_TOKEN_1 ||
            token == BASEPOOL_TOKEN_2 ||
            Pendle3CrvHelper.is3CrvToken(token));
    }
}
