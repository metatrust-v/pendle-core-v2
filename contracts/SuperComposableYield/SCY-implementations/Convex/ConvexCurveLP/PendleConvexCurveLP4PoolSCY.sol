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

        _safeApprove(BASEPOOL_TOKEN_1, BASE_CRV_POOL, type(uint256).max);
        _safeApprove(BASEPOOL_TOKEN_2, BASE_CRV_POOL, type(uint256).max);
        _safeApprove(BASEPOOL_TOKEN_3, BASE_CRV_POOL, type(uint256).max);
        _safeApprove(BASEPOOL_TOKEN_4, BASE_CRV_POOL, type(uint256).max);
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

    function isCrvBaseToken(address token) public view override returns (bool res) {
        return (token == BASEPOOL_TOKEN_1 ||
            token == BASEPOOL_TOKEN_2 ||
            token == BASEPOOL_TOKEN_3 ||
            token == BASEPOOL_TOKEN_4);
    }

    function _assignAmountsToCrvBaseIndex(address crvBaseToken, uint256 amountDeposited)
        internal
        view
        override
        returns (uint256[] memory res)
    {
        res = new uint256[](BASEPOOL_TOKEN_LENGTH);
        res[_getIndexOfCrvBaseToken(crvBaseToken)] = amountDeposited;
    }
}
