// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./base/PendleAuraBalancerLPSY.sol";
import "../../../../interfaces/Balancer/IVault.sol";
import "../../../../interfaces/Balancer/IBasePool.sol";
import "./base/StableMath.sol";
import "./base/StablePoolUserData.sol";
import "./base/Balancer3EthPoolHelper.sol";

// TODO support recovery mode
contract PendleAuraWstEthREthFrxEthSY is PendleAuraBalancerLPSY {
    using SafeERC20 for IERC20;

    uint256 constant PID = 13;
    address constant POOL = 0x8e85e97ed19C0fa13B2549309965291fbbc0048b;

    constructor(
        string memory _name,
        string memory _symbol
    ) PendleAuraBalancerLPSY(_name, _symbol, POOL, PID) {}

    function getTokensIn() public view virtual override returns (address[] memory res) {
        return _getPoolTokens();
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        return _getPoolTokens();
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/JOIN
    //////////////////////////////////////////////////////////////*/

    function _depositToBalancerSingleToken(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal virtual override returns (uint256) {
        uint256 balanceBefore = IERC20(balancerLp).balanceOf(address(this));

        // transfer directly to the vault to use internal balance
        IVault.JoinPoolRequest memory request = _assembleJoinRequest(
            tokenIn,
            amountTokenToDeposit
        );

        IERC20(tokenIn).safeTransfer(BALANCER_VAULT, amountTokenToDeposit);
        IVault(BALANCER_VAULT).joinPool(balancerPoolId, address(this), address(this), request);

        // calculate shares received and return
        uint256 balanceAfter = IERC20(balancerLp).balanceOf(address(this));
        return balanceAfter - balanceBefore;
    }

    function _previewDepositToBalancerSingleToken(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 amountLpOut) {
        IVault.JoinPoolRequest memory request = _assembleJoinRequest(
            tokenIn,
            amountTokenToDeposit
        );
        amountLpOut = Balancer3EthPoolHelper.joinPoolPreview(
            balancerPoolId,
            address(this),
            address(this),
            request
        );
    }

    function _assembleJoinRequest(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view returns (IVault.JoinPoolRequest memory request) {
        // max amounts in
        address[] memory assets = _getPoolTokens();
        uint256[] memory maxAmountsIn = new uint256[](assets.length);

        // encode user data
        StablePoolUserData.JoinKind joinKind = StablePoolUserData
            .JoinKind
            .EXACT_TOKENS_IN_FOR_BPT_OUT;
        uint256[] memory amountsIn = new uint256[](assets.length);
        uint256 minimumBPT = 0;
        for (uint256 i = 0; i < assets.length; ++i) {
            if (assets[i] == tokenIn) {
                amountsIn[i] = amountTokenToDeposit;
                break;
            }
        }
        bytes memory userData = abi.encode(joinKind, amountsIn, minimumBPT);

        // assemble joinpoolrequest
        request = IVault.JoinPoolRequest(assets, maxAmountsIn, userData, true);
    }

    /*///////////////////////////////////////////////////////////////
                    REDEEM/EXIT
    //////////////////////////////////////////////////////////////*/

    function _redeemFromBalancerSingleToken(
        address tokenOut,
        uint256 amountLpToRedeem
    ) internal virtual override returns (uint256) {
        IVault.ExitPoolRequest memory request = _assembleExitRequest(tokenOut, amountLpToRedeem);

        IVault(BALANCER_VAULT).exitPool(
            balancerPoolId,
            address(this),
            payable(address(this)),
            request
        );

        // tokens received = tokens out
        return IERC20(tokenOut).balanceOf(address(this));
    }

    function _previewRedeemFromBalancerSingleToken(
        address tokenOut,
        uint256 amountLpToRedeem
    ) internal view virtual override returns (uint256 amountTokenOut) {
        IVault.ExitPoolRequest memory request = _assembleExitRequest(tokenOut, amountLpToRedeem);

        amountTokenOut = Balancer3EthPoolHelper.exitPoolPreview(
            balancerPoolId,
            address(this),
            address(this),
            request
        );
    }

    function _assembleExitRequest(
        address tokenOut,
        uint256 amountLpToRedeem
    ) internal view returns (IVault.ExitPoolRequest memory request) {
        address[] memory assets = _getPoolTokens();
        uint256[] memory minAmountsOut = new uint256[](assets.length);

        // encode user data
        StablePoolUserData.ExitKind exitKind = StablePoolUserData
            .ExitKind
            .EXACT_BPT_IN_FOR_ONE_TOKEN_OUT;
        uint256 bptAmountIn = amountLpToRedeem;
        uint256 exitTokenIndex;
        for (uint256 i = 0; i < assets.length; ++i) {
            if (assets[i] == tokenOut) {
                exitTokenIndex = i;
                break;
            }
        }

        bytes memory userData = abi.encode(exitKind, bptAmountIn, exitTokenIndex);

        // assemble exitpoolrequest
        request = IVault.ExitPoolRequest(assets, minAmountsOut, userData, false);
    }
}