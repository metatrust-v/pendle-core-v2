// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./libraries/TokenHelper.sol";
import "./libraries/math/Math.sol";
import "./libraries/Errors.sol";
import "./BulkSellerMathCore.sol";
import "../interfaces/IStandardizedYield.sol";

contract BulkSellerSY is TokenHelper {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using BulkSellerMathCore for BulkSellerState;

    struct BulkSellerStorage {
        uint128 sellOutRate; // higher than actual cost to make SY
        uint128 buyInRate; // lower than actual cost to redeem SY
        uint128 totalSy;
        uint128 totalToken;
    }

    address public immutable token;
    address public immutable SY;
    BulkSellerStorage public _storage;

    constructor(address token_, address SY_) {
        token = token_;
        SY = SY_;
    }

    // TODO: not yet verify balance and all

    function swapExactTokenForSy(address receiver, uint256 exactTokenIn)
        external
        returns (uint256 netSyOut)
    {
        BulkSellerState memory state = readState();
        netSyOut = state.swapExactTokenForSy(exactTokenIn);

        if (receiver != address(this)) IERC20(SY).safeTransfer(receiver, netSyOut);

        _writeState(state);
    }

    function swapExactSyForToken(address receiver, uint256 exactSyIn)
        external
        returns (uint256 netTokenOut)
    {
        BulkSellerState memory state = readState();
        netTokenOut = state.swapExactSyForToken(exactSyIn);

        if (receiver != address(this)) IERC20(token).safeTransfer(receiver, netTokenOut);

        _writeState(state);
    }

    function readState() internal view returns (BulkSellerState memory state) {
        BulkSellerStorage storage s = _storage;
        state.tokenToSyRate = s.tokenToSyRate;
        state.syToTokenRate = s.syToTokenRate;
        state.totalSy = s.totalSy;
        state.totalToken = s.totalToken;
    }

    function _writeState(BulkSellerState memory state) internal {
        BulkSellerStorage storage s = _storage;
        s.tokenToSyRate = state.tokenToSyRate.Uint128();
        s.syToTokenRate = state.syToTokenRate.Uint128();
        s.totalSy = state.totalSy.Uint128();
        s.totalToken = state.totalToken.Uint128();
    }

    //////////////////////////

    function reBalance(uint256 targetSyProportion) external {
        BulkSellerState memory state = readState();
        (uint256 netTokenToMint, uint256 netSyToRedeem) = state.reBalance(targetSyProportion);
        if (netTokenToMint > 0) {
            _safeApprove(token, SY, netTokenToMint);
            IStandardizedYield(SY).deposit(address(this), token, netTokenToMint, minSharesOut);
        }
    }

    function getTokenProportion() external view returns (uint256) {
        BulkSellerState memory state = readState();
        return state.getTokenProportion();
    }
}
