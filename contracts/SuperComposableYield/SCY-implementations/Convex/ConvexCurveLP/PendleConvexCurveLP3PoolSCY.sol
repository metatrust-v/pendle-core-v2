// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./PendleConvexCurveLPSCY.sol";

contract PendleConvexCurveLP3PoolSCY is PendleConvexCurveLPSCY {
    address public immutable BASEPOOL_TOKEN_1;
    address public immutable BASEPOOL_TOKEN_2;
    address public immutable BASEPOOL_TOKEN_3;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _pid,
        address _convexBooster,
        address _crvLpToken,
        address _cvx,
        address _baseCrvPool,
        address[] memory _currentExtraRewards,
        address[3] memory _basePoolTokens
    )
        PendleConvexCurveLPSCY(
            _name,
            _symbol,
            _pid,
            _convexBooster,
            _crvLpToken,
            _cvx,
            _baseCrvPool,
            _currentExtraRewards
        )
    {
        BASEPOOL_TOKEN_1 = _basePoolTokens[0];
        BASEPOOL_TOKEN_2 = _basePoolTokens[1];
        BASEPOOL_TOKEN_3 = _basePoolTokens[2];

        _safeApprove(BASEPOOL_TOKEN_1, BASE_CRV_POOL, type(uint256).max);
        _safeApprove(BASEPOOL_TOKEN_2, BASE_CRV_POOL, type(uint256).max);
        _safeApprove(BASEPOOL_TOKEN_3, BASE_CRV_POOL, type(uint256).max);
    }

    function getTokensIn() public view override returns (address[] memory res) {
        res = new address[](5);
        res[0] = CRV_LP_TOKEN;
        res[1] = BASEPOOL_TOKEN_1;
        res[2] = BASEPOOL_TOKEN_2;
        res[3] = BASEPOOL_TOKEN_3;
    }

    function getTokensOut() public view override returns (address[] memory res) {
        res = new address[](5);
        res[0] = CRV_LP_TOKEN;
        res[1] = BASEPOOL_TOKEN_1;
        res[2] = BASEPOOL_TOKEN_2;
        res[3] = BASEPOOL_TOKEN_3;
    }

    function isValidTokenIn(address token) public view override returns (bool res) {
        res = (token == CRV_LP_TOKEN ||
            token == BASEPOOL_TOKEN_1 ||
            token == BASEPOOL_TOKEN_2 ||
            token == BASEPOOL_TOKEN_3);
    }

    function isValidTokenOut(address token) public view override returns (bool res) {
        res = (token == CRV_LP_TOKEN ||
            token == BASEPOOL_TOKEN_1 ||
            token == BASEPOOL_TOKEN_2 ||
            token == BASEPOOL_TOKEN_3);
    }

    function _getBaseTokenIndex(address crvBaseToken)
        internal
        view
        override
        returns (uint256 index)
    {
        if (crvBaseToken == BASEPOOL_TOKEN_1) {
            index = 0;
        } else if (crvBaseToken == BASEPOOL_TOKEN_2) {
            index = 1;
        } else {
            index = 2;
        }
    }

    function _isBaseToken(address token) internal view override returns (bool res) {
        return (token == BASEPOOL_TOKEN_1 ||
            token == BASEPOOL_TOKEN_2 ||
            token == BASEPOOL_TOKEN_3);
    }

    function getBaseTokenPoolLength() public pure override returns (uint256 length) {
        length = 3;
    }
}
