// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;
import "../../periphery/BoringOwnableUpgradeable.sol";
import "../../interfaces/IPAllAction.sol";
import "../../libraries/helpers/TokenHelper.sol";
import "../../libraries/math/Math.sol";

contract PendleBatchSeller is BoringOwnableUpgradeable, TokenHelper {
    using Math for uint256;

    address public immutable router;
    address public immutable token;
    address public immutable PT;

    uint256 public feeRatio;
    uint256 public price;

    constructor(
        address _router,
        address _token,
        address _PT,
        uint256 _feeRatio
    ) initializer {
        __BoringOwnable_init();
        router = _router;
        token = _token;
        PT = _PT;
        setFeeRatio(_feeRatio);
    }

    function buyExactPt(uint256 netPtOut, uint256 maxTokenIn)
        external
        returns (uint256 netTokenIn)
    {
        netTokenIn = calcTokenIn(netPtOut);
        require(netPtOut <= _selfBalance(PT), "netPtOut exceeds balance");
        require(netTokenIn <= maxTokenIn, "netTokenIn exceeds maxTokenIn");

        _transferIn(token, msg.sender, netTokenIn);
        _transferOut(PT, msg.sender, netPtOut);
    }

    function buyPtWithExactToken(uint256 netTokenIn, uint256 minPtOut)
        external
        returns (uint256 netPtOut)
    {
        netPtOut = calcPtOut(netTokenIn);
        require(netPtOut <= _selfBalance(PT), "netPtOut exceeds balance");
        require(netPtOut >= minPtOut, "insufficient pt out");

        _transferIn(token, msg.sender, netTokenIn);
        _transferOut(PT, msg.sender, netPtOut);
    }

    function sellPt(uint256 amountPtToSell, uint256 rawPrice) external onlyOwner {
        uint256 feeIncludedPrice = _calcPriceAfterFee(rawPrice);
        uint256 amountPtLeftOver = _selfBalance(PT);

        price =
            (price * amountPtLeftOver + feeIncludedPrice * amountPtToSell) /
            (amountPtLeftOver + amountPtToSell);

        _transferIn(PT, msg.sender, amountPtToSell);
    }

    function sellPtAndSetPrice(uint256 amountPtToSell, uint256 _price) external onlyOwner {
        setPrice(_calcPriceAfterFee(_price));
        _transferIn(PT, msg.sender, amountPtToSell);
    }

    function setFeeRatio(uint256 _feeRatio) public onlyOwner {
        feeRatio = _feeRatio;
    }

    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }

    function calcTokenIn(uint256 netPtOut) public view returns (uint256 netTokenIn) {
        netTokenIn = (netPtOut * price).rawDivUp(Math.ONE);
    }

    function calcPtOut(uint256 netTokenIn) public view returns (uint256 netPtOut) {
        netPtOut = netTokenIn.divDown(price);
    }

    function _calcPriceAfterFee(uint256 _price) internal view returns (uint256) {
        return (_price * (Math.ONE + feeRatio)) / Math.ONE;
    }
}
