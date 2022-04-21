// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./PendleBaseToken.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../SuperComposableYield/ISuperComposableYield.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPMarketFactory.sol";
import "../interfaces/IPMarketSwapCallback.sol";
import "../interfaces/IPMarketAddRemoveCallback.sol";

import "../libraries/math/LogExpMath.sol";
import "../libraries/math/Math.sol";
import "../libraries/math/MarketMathAux.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// solhint-disable reason-string
contract PendleMarket is PendleBaseToken, IPMarket, ReentrancyGuard {
    using Math for uint256;
    using Math for int256;
    using Math for uint128;
    using LogExpMath for uint256;
    using MarketMathAux for MarketState;
    using MarketMathCore for MarketState;
    using SafeERC20 for IERC20;

    string private constant NAME = "Pendle Market";
    string private constant SYMBOL = "PENDLE-LPT";

    address public immutable OT;
    address public immutable SCY;
    address public immutable YT;

    int256 public immutable scalarRoot;
    int256 public immutable initialAnchor;

    MarketStorage public marketStorage;

    constructor(
        address _OT,
        int256 _scalarRoot,
        int256 _initialAnchor
    ) PendleBaseToken(NAME, SYMBOL, 18, IPOwnershipToken(_OT).expiry()) {
        OT = _OT;
        SCY = IPOwnershipToken(_OT).SCY();
        YT = IPOwnershipToken(_OT).YT();
        scalarRoot = _scalarRoot;
        initialAnchor = _initialAnchor;
    }

    function addLiquidity(
        address receiver,
        uint256 scyDesired,
        uint256 otDesired,
        bytes calldata data
    )
        external
        nonReentrant
        returns (
            uint256 lpToAccount,
            uint256 scyUsed,
            uint256 otUsed
        )
    {
        MarketState memory market = readState(true);
        SCYIndex index = SCYIndexLib.newIndex(SCY);

        uint256 lpToReserve;
        (lpToReserve, lpToAccount, scyUsed, otUsed) = market.addLiquidity(
            index,
            scyDesired,
            otDesired,
            true
        );

        // initializing the market
        if (lpToReserve != 0) {
            market.setInitialLnImpliedRate(index, initialAnchor, block.timestamp);
            _mint(address(1), lpToReserve);
        }

        _mint(receiver, lpToAccount);

        if (data.length > 0) {
            IPMarketAddRemoveCallback(msg.sender).addLiquidityCallback(
                lpToAccount,
                scyUsed,
                otUsed,
                data
            );
        }

        require(market.totalOt.Uint() <= IERC20(OT).balanceOf(address(this)));
        require(market.totalScy.Uint() <= IERC20(SCY).balanceOf(address(this)));

        _writeState(market);

        emit AddLiquidity(receiver, lpToAccount, scyUsed, otUsed);
    }

    function removeLiquidity(
        address receiver,
        uint256 lpToRemove,
        bytes calldata data
    ) external nonReentrant returns (uint256 scyToAccount, uint256 otToAccount) {
        MarketState memory market = readState(true);

        (scyToAccount, otToAccount) = market.removeLiquidity(lpToRemove, true);

        IERC20(SCY).safeTransfer(receiver, scyToAccount);
        IERC20(OT).safeTransfer(receiver, otToAccount);

        if (data.length > 0) {
            IPMarketAddRemoveCallback(msg.sender).removeLiquidityCallback(
                lpToRemove,
                scyToAccount,
                otToAccount,
                data
            );
        }

        _burn(address(this), lpToRemove);

        _writeState(market);
        emit RemoveLiquidity(receiver, lpToRemove, scyToAccount, otToAccount);
    }

    function swapExactOtForScy(
        address receiver,
        uint256 exactOtIn,
        uint256 minScyOut,
        bytes calldata data
    ) external nonReentrant returns (uint256 netScyOut, uint256 netScyToReserve) {
        require(block.timestamp < expiry, "MARKET_EXPIRED");

        MarketState memory market = readState(true);

        (netScyOut, netScyToReserve) = market.swapExactOtForScy(
            SCYIndexLib.newIndex(SCY),
            exactOtIn,
            block.timestamp,
            true
        );
        require(netScyOut >= minScyOut, "insufficient scy out");
        IERC20(SCY).safeTransfer(receiver, netScyOut);
        IERC20(SCY).safeTransfer(market.treasury, netScyToReserve);

        if (data.length > 0) {
            IPMarketSwapCallback(msg.sender).swapCallback(exactOtIn.neg(), netScyOut.Int(), data);
        }

        // have received enough OT
        require(market.totalOt.Uint() <= IERC20(OT).balanceOf(address(this)));
        _writeState(market);

        emit Swap(receiver, exactOtIn.neg(), netScyOut.Int(), netScyToReserve);
    }

    function swapScyForExactOt(
        address receiver,
        uint256 exactOtOut,
        uint256 maxScyIn,
        bytes calldata data
    ) external nonReentrant returns (uint256 netScyIn, uint256 netScyToReserve) {
        require(block.timestamp < expiry, "MARKET_EXPIRED");

        MarketState memory market = readState(true);

        (netScyIn, netScyToReserve) = market.swapScyForExactOt(
            SCYIndexLib.newIndex(SCY),
            exactOtOut,
            block.timestamp,
            true
        );
        require(netScyIn <= maxScyIn, "scy in exceed limit");
        IERC20(OT).safeTransfer(receiver, exactOtOut);
        IERC20(SCY).safeTransfer(market.treasury, netScyToReserve);

        if (data.length > 0) {
            IPMarketSwapCallback(msg.sender).swapCallback(exactOtOut.Int(), netScyIn.neg(), data);
        }

        // have received enough SCY
        require(market.totalScy.Uint() <= IERC20(SCY).balanceOf(address(this)));
        _writeState(market);

        emit Swap(receiver, exactOtOut.Int(), netScyIn.neg(), netScyToReserve);
    }

    /// @dev this function is just a place holder. Later on the rewards will be transferred to the liquidity minining
    /// instead
    function redeemScyReward() external returns (uint256[] memory outAmounts) {
        outAmounts = ISuperComposableYield(SCY).redeemReward(address(this));
    }

    function readState(bool updateRateOracle) public view returns (MarketState memory market) {
        MarketStorage storage store = marketStorage;
        market.totalOt = store.totalOt;
        market.totalScy = store.totalScy;
        market.totalLp = totalSupply().Int();
        market.oracleRate = store.oracleRate;

        (
            market.treasury,
            market.lnFeeRateRoot,
            market.rateOracleTimeWindow,
            market.reserveFeePercent
        ) = IPMarketFactory(factory).marketConfig();

        market.scalarRoot = scalarRoot;
        market.expiry = expiry;

        market.lastLnImpliedRate = store.lastLnImpliedRate;
        market.lastTradeTime = store.lastTradeTime;

        if (updateRateOracle) {
            market.updateNewRateOracle(block.timestamp);
        }
    }

    function _writeState(MarketState memory market) internal {
        MarketStorage storage store = marketStorage;

        store.totalOt = market.totalOt.Int128();
        store.totalScy = market.totalScy.Int128();
        store.lastLnImpliedRate = market.lastLnImpliedRate.Uint112();
        store.oracleRate = market.oracleRate.Uint112();
        store.lastTradeTime = market.lastTradeTime.Uint32();

        emit UpdateImpliedRate(block.timestamp, market.lastLnImpliedRate);
    }

    function readTokens()
        external
        view
        returns (
            ISuperComposableYield _SCY,
            IPOwnershipToken _OT,
            IPYieldToken _YT
        )
    {
        _SCY = ISuperComposableYield(SCY);
        _OT = IPOwnershipToken(OT);
        _YT = IPYieldToken(YT);
    }
}
