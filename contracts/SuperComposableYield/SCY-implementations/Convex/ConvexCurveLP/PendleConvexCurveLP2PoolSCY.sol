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

        _safeApprove(BASEPOOL_TOKEN_1, BASE_CRV_POOL, type(uint256).max);
        _safeApprove(BASEPOOL_TOKEN_2, BASE_CRV_POOL, type(uint256).max);
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](4);
        res[0] = CRV_LP_TOKEN;
        res[1] = W_CRV_LP_TOKEN;
        res[2] = BASEPOOL_TOKEN_1;
        res[3] = BASEPOOL_TOKEN_2;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](4);
        res[0] = CRV_LP_TOKEN;
        res[1] = W_CRV_LP_TOKEN;
        res[2] = BASEPOOL_TOKEN_1;
        res[3] = BASEPOOL_TOKEN_2;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool res) {
        res = (token == CRV_LP_TOKEN ||
            token == W_CRV_LP_TOKEN ||
            token == BASEPOOL_TOKEN_1 ||
            token == BASEPOOL_TOKEN_2);
    }

    function isValidTokenOut(address token) public view virtual override returns (bool res) {
        res = (token == CRV_LP_TOKEN ||
            token == W_CRV_LP_TOKEN ||
            token == BASEPOOL_TOKEN_1 ||
            token == BASEPOOL_TOKEN_2);
    }

    function _getBaseTokenIndex(address crvBaseToken)
        internal
        view
        virtual
        override
        returns (uint256 index)
    {
        if (crvBaseToken == BASEPOOL_TOKEN_1) {
            index = 0;
        } else {
            index = 1;
        }
    }

    function _isBaseToken(address token) internal view virtual override returns (bool res) {
        return (token == BASEPOOL_TOKEN_1 || token == BASEPOOL_TOKEN_2);
    }

    function getBaseTokenPoolLength() public pure virtual override returns (uint256 length) {
        length = 2;
    }
}
