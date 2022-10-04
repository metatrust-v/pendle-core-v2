// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../periphery/BoringOwnableUpgradeable.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPAllAction.sol";
import "../interfaces/IPBatchSeller.sol";

contract PtAMMArb is Initializable, UUPSUpgradeable, BoringOwnableUpgradeable {
    using SafeERC20 for IERC20;

    address public immutable router;
    address public immutable market;

    ISuperComposableYield public immutable SCY;
    IPPrincipalToken public immutable PT;
    IPYieldToken public immutable YT;

    address public immutable baseToken;
    address public immutable batchSeller;
    uint256 public minProfit;

    using MarketMathCore for MarketState;

    constructor(
        address _router,
        address _market,
        address _baseToken,
        address _batchSeller
    ) initializer {
        router = _router;
        market = _market;
        baseToken = _baseToken;
        (SCY, PT, YT) = IPMarket(market).readTokens();
        batchSeller = _batchSeller;
        IERC20(_baseToken).approve(_batchSeller, type(uint256).max);
    }

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function arbitrage(uint256 netTokenIn) external returns (uint256 profit) {
        // profit check
        {
            uint256 amountPtOut = IPBatchSeller(batchSeller).calcPtOut(netTokenIn);

            MarketState memory state = IPMarket(market).readState();
            PYIndex index = PYIndex.wrap(YT.pyIndexCurrent());

            (uint256 netScyToAccount, ) = state.swapExactPtForScy(
                index,
                amountPtOut,
                block.timestamp
            );
            uint256 netTokenOut = SCY.previewRedeem(baseToken, netScyToAccount);

            require(netTokenOut >= netTokenIn, "arb: no profit");
            require(netTokenOut - netTokenIn >= minProfit, "arb: min profit not achieved");
        }

        // arbitrage execution
        {
            uint256 amountPtOut = IPBatchSeller(batchSeller).buyPtWithExactToken(
                market,
                netTokenIn,
                0
            );
            (uint256 amountScyOut, ) = IPMarket(market).swapExactPtForScy(
                address(SCY),
                amountPtOut,
                abi.encode()
            );
            uint256 netTokenOut = SCY.redeem(address(this), amountScyOut, baseToken, 0, true);
            profit = netTokenOut - netTokenIn;
        }
    }

    function setMinProfit(uint256 _minProfit) external onlyOwner {
        minProfit = _minProfit;
    }

    function fundBaseToken(uint256 amount) external {
        IERC20(baseToken).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdrawBaseToken(uint256 amount) external onlyOwner {
        IERC20(baseToken).safeTransfer(msg.sender, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
