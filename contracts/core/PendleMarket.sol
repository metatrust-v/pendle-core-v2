// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./Base/PendleBaseToken.sol";
import "../interfaces/IPMarketCallback.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../interfaces/IPLiquidYieldToken.sol";
import "../interfaces/IPMarket.sol";

import "../libraries/math/LogExpMath.sol";
import "../libraries/math/FixedPoint.sol";
import "../libraries/math/MarketMathLib.sol";

// solhint-disable reason-string
contract PendleMarket is PendleBaseToken, IPMarket {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using LogExpMath for uint256;
    using MarketMathLib for MarketParameters;
    // make it ultra simple

    // careful, the reserve of the market shouldn't be interferred by external factors
    // maybe convert all time to uint32?
    // do the stateful & view stuff?
    // consider not using ERC20 to pack variables into struct
    string private constant NAME = "Pendle Market";
    string private constant SYMBOL = "PENDLE-LPT";
    uint256 private constant MINIMUM_LIQUIDITY = 10**3;
    uint8 private constant DECIMALS = 18;
    int256 internal constant RATE_PRECISION = 1e9;

    address public immutable OT;
    address public immutable LYT;

    uint256 public reserveOT;
    uint256 public reserveLYT;

    uint256 public immutable scalarRoot;
    uint256 public immutable feeRateRoot; // allow fee to be changable
    uint8 public immutable reserveFeePercent;

    int256 public savedAnchorRate;
    uint256 public start;
    uint256 public savedIntRate;

    MarketStorage public _marketState;

    constructor(
        address _OT,
        uint256 _feeRateRoot,
        uint256 _scalarRoot,
        int256 _anchorRoot,
        uint8 _reserveFeePercent
    ) PendleBaseToken(NAME, SYMBOL, 18, IPOwnershipToken(_OT).expiry()) {
        OT = _OT;
        LYT = IPOwnershipToken(_OT).LYT();
        feeRateRoot = _feeRateRoot;
        scalarRoot = _scalarRoot;
        savedAnchorRate = _anchorRoot;
        reserveFeePercent = _reserveFeePercent;
    }

    function mint(
        address recipient,
        uint256 lytDesired,
        uint256 otDesired
    )
        external
        returns (
            uint256 lpToUser,
            uint256 lytNeed,
            uint256 otNeed
        )
    {
        MarketParameters memory market;
        _readState(market);

        uint256 lpToReserve;
        (lpToReserve, lpToUser, lytNeed, otNeed) = market.addLiquidity(lytDesired, otDesired);

        if (lpToReserve != 0) {
            _mint(address(1), lpToReserve);
        }

        _mint(recipient, lpToUser);
        // TODO: add callback to router

        _writeAndVerifyState(market);
    }

    function burn(address recipient) external returns (uint256 lytOut, uint256 otOut) {
        MarketParameters memory market;
        _readState(market);

        uint256 lpToRemove = balanceOf(address(this));

        (lytOut, otOut) = market.removeLiquidity(lpToRemove);

        _burn(address(this), lpToRemove);
        IERC20(LYT).transfer(recipient, lytOut);
        IERC20(OT).transfer(recipient, otOut);

        // TODO: no callback here, but there are callbacks at other functions
        _writeAndVerifyState(market);
    }

    function swapExactOTForLYT(
        address recipient,
        uint256 otIn,
        bytes calldata cbData
    ) external returns (uint256 lytOut, bytes memory cbRes) {
        int256 lytToAccount;
        (lytToAccount, cbRes) = _swap(recipient, otIn.toInt().neg(), cbData);
        lytOut = lytToAccount.toUint();
    }

    function swapLYTForExactOT(
        address recipient,
        uint256 otOut,
        bytes calldata cbData
    ) external returns (uint256 lytOut, bytes memory cbRes) {
        int256 lytToAccount;
        (lytToAccount, cbRes) = _swap(recipient, otOut.toInt(), cbData);
        lytOut = lytToAccount.neg().toUint();
    }

    function _swap(
        address recipient,
        int256 otToAccount,
        bytes calldata cbData
    ) internal returns (int256 netLytToAccount, bytes memory cbRes) {
        require(block.timestamp < expiry, "MARKET_EXPIRED");

        MarketParameters memory market;
        _readState(market);

        uint256 netLytToReserve;

        (netLytToAccount, netLytToReserve) = market.calculateTrade(
            otToAccount,
            market.expiry - block.timestamp
        );

        if (netLytToAccount > 0) {
            // need to push LYT & pull OT
            IERC20(LYT).transfer(recipient, netLytToAccount.toUint());
        } else {
            // need to push OT & pull LYT
            IERC20(OT).transfer(recipient, otToAccount.neg().toUint());
        }
        cbRes = IPMarketCallback(msg.sender).callback(otToAccount, netLytToAccount, cbData);

        // IERC20(LYT).transfer(treasury, netLytToReserve);
        _writeAndVerifyState(market);
    }

    function _readState(MarketParameters memory market) internal {
        MarketStorage storage store = _marketState;
        market.expiry = expiry;
        market.totalOt = store.totalOt;
        market.totalLyt = store.totalLyt;
        market.totalLp = totalSupply();
        market.lastImpliedRate = store.lastImpliedRate;
        market.lytRate = IPLiquidYieldToken(LYT).exchangeRateCurrent();
        market.feeRateRoot = feeRateRoot;
        market.reserveFeePercent = reserveFeePercent;
    }

    function _writeAndVerifyState(MarketParameters memory market) internal {
        MarketStorage storage store = _marketState;
        require(market.totalOt <= IERC20(OT).balanceOf(address(this)));
        require(market.totalLyt <= IERC20(LYT).balanceOf(address(this)));
        // shall we verify lp here?
        // hmm should we verify the sum right after callback instead?

        store.totalOt = market.totalOt.toUint128();
        store.totalLyt = market.totalLyt.toUint128();
        store.lastImpliedRate = market.lastImpliedRate.toUint32();
    }
}
