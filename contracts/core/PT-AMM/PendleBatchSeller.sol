// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;
import "../../periphery/BoringOwnableUpgradeable.sol";
import "../../interfaces/IPAllAction.sol";
import "../../interfaces/IPBatchSeller.sol";
import "../../interfaces/IPMarket.sol";
import "../../libraries/helpers/TokenHelper.sol";
import "../../libraries/math/Math.sol";

contract PendleBatchSeller is BoringOwnableUpgradeable, TokenHelper, IPBatchSeller {
    using Math for uint256;
    using MarketMathCore for MarketState;

    address public immutable router;
    address public immutable token;

    address public immutable market;
    address public immutable SCY;
    address public immutable PT;
    address public immutable YT;

    uint256 public feeRatio;
    uint256 public batchPrice;

    constructor(
        address _router,
        address _token,
        address _market,
        uint256 _initialFeeRatio
    ) initializer {
        __BoringOwnable_init();
        router = _router;
        token = _token;
        market = _market;
        (SCY, PT, YT) = _readMarketTokens(_market);
        setFeeRatio(_initialFeeRatio);
    }

    function _readMarketTokens(address _market)
        internal
        view
        returns (
            address,
            address,
            address
        )
    {
        (ISuperComposableYield _SCY, IPPrincipalToken _PT, IPYieldToken _YT) = IPMarket(_market)
            .readTokens();
        return (address(_SCY), address(_PT), address(_YT));
    }

    function buyExactPt(
        address receiver,
        uint256 netPtOut,
        uint256 maxTokenIn
    ) external returns (uint256 netTokenIn) {
        netTokenIn = calcTokenIn(netPtOut);
        require(netPtOut <= _selfBalance(PT), "netPtOut exceeds balance");
        require(netTokenIn <= maxTokenIn, "netTokenIn exceeds maxTokenIn");

        _transferIn(token, msg.sender, netTokenIn);
        _transferOut(PT, receiver, netPtOut);
    }

    function buyPtWithExactToken(
        address receiver,
        uint256 netTokenIn,
        uint256 minPtOut
    ) external returns (uint256 netPtOut) {
        netPtOut = calcPtOut(netTokenIn);
        require(netPtOut >= minPtOut, "insufficient pt out");

        _transferIn(token, msg.sender, netTokenIn);
        _transferOut(PT, receiver, netPtOut);
    }

    function sellPt(uint256 amountPtToSell, uint256 rawPrice) external onlyOwner {
        uint256 feeIncludedPrice = _calcPriceAfterFee(rawPrice);
        uint256 amountPtLeftOver = _selfBalance(PT);

        batchPrice =
            (batchPrice * amountPtLeftOver + feeIncludedPrice * amountPtToSell) /
            (amountPtLeftOver + amountPtToSell);

        _transferIn(PT, msg.sender, amountPtToSell);
    }

    function sellPtAndSetBatchPrice(uint256 amountPtToSell, uint256 _price) external onlyOwner {
        setBatchPrice(_calcPriceAfterFee(_price));
        _transferIn(PT, msg.sender, amountPtToSell);
    }

    function setFeeRatio(uint256 _feeRatio) public onlyOwner {
        feeRatio = _feeRatio;
    }

    function setBatchPrice(uint256 _price) public onlyOwner {
        batchPrice = _price;
    }

    function calcTokenIn(uint256 netPtOut) public returns (uint256 netTokenIn) {
        uint256 price = getPrice(netPtOut);
        netTokenIn = (netPtOut * price).rawDivUp(Math.ONE);
    }

    function calcPtOut(uint256 netTokenIn) public returns (uint256 netPtOut) {
        uint256 price = getPrice(netTokenIn.divDown(batchPrice));
        netPtOut = netTokenIn.divDown(price);
        require(netPtOut <= _selfBalance(PT), "insufficient PT out");
    }

    function _calcPriceAfterFee(uint256 _price) internal view returns (uint256) {
        return (_price * (Math.ONE + feeRatio)) / Math.ONE;
    }

    function getPrice(uint256 netPtOut) public returns (uint256) {
        return Math.max(batchPrice, _getMarketSwapPrice(netPtOut));
    }

    function _getMarketSwapPrice(uint256 netPtOut) internal returns (uint256) {
        MarketState memory state = IPMarket(market).readState();
        PYIndex index = PYIndex.wrap(IPYieldToken(YT).pyIndexCurrent());
        (uint256 netScyIn, ) = state.swapScyForExactPt(index, netPtOut, block.timestamp);
        uint256 netTokenIn = ISuperComposableYield(SCY).previewRedeem(token, netScyIn);
        return netTokenIn.divUp(netPtOut);
    }
}
