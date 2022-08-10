pragma solidity ^0.8.0;
import "./IQiTokenTest.sol";
import "../interfaces/ISuperComposableYield.sol";
import "../core/YieldContracts/PendleYieldToken.sol";
import "../core/YieldContracts/PendlePrincipalToken.sol";
import "../core/Market/PendleMarket.sol";

contract FundKeeper {
    constructor() {}

    function mintSCYNative(address scy) public payable {
        require(msg.value > 0, "zero native");
        ISuperComposableYield(scy).deposit{ value: msg.value }(
            address(this),
            address(0),
            msg.value,
            0
        );
    }

    function redeemSCYNative(address scy) public {
        uint256 amount = ISuperComposableYield(scy).balanceOf(address(this));
        require(amount > 0, "zero share");
        ISuperComposableYield(scy).redeem(address(this), amount, address(0), 0);
    }

    function transferTo(
        IERC20 token,
        address to,
        uint256 amount
    ) public {
        token.transfer(to, amount);
    }

    function transferToMany(
        IERC20 token,
        address[] calldata to,
        uint256 amount
    ) public {
        for (uint8 i = 0; i < to.length; ++i) {
            require(
                token.balanceOf(address(this)) >= amount,
                "fund keeper does not have enough fund"
            );
            token.transfer(to[i], amount);
        }
    }

    function mintScySingleBase(
        address scy,
        address base,
        uint256 amount
    ) public returns (uint256) {
        IERC20(base).approve(scy, amount);
        return ISuperComposableYield(scy).deposit(address(this), base, amount, 0);
    }

    function mintYT(
        address scy,
        address base,
        address yt,
        uint256 amountBase
    ) public returns (uint256) {
        uint256 scyAmount = mintScySingleBase(scy, base, amountBase);
        IERC20(scy).transfer(yt, scyAmount);
        return PendleYieldToken(yt).mintPY(address(this), address(this));
    }

    function depositBenqi(IQiTokenTest qiToken, uint256 amount) public {
        IERC20 underlying = IERC20(qiToken.underlying());
        underlying.approve(address(qiToken), amount);
        qiToken.mint(amount);
        qiToken.borrow((amount * 7) / 10);
    }

    function depositBenqiAVAX(address qiAVAX, uint256 amount) public payable {
        require(msg.value >= amount, "not enough money");
        IQiTokenTest(qiAVAX).mint{ value: amount }();
        IQiTokenTest(qiAVAX).borrow(amount / 2);
    }

    function redeemAllPY(PendleYieldToken yt) public {
        IERC20 pt = IERC20(yt.PT());
        pt.transfer(address(pt), pt.balanceOf(address(this)));
        yt.transfer(address(pt), yt.balanceOf(address(this)));
    }

    function redeemPYAfterExpiryPull(PendleYieldToken yt, uint256 amount) public {
        require(yt.balanceOf(address(yt)) == 0, "NONEMPTY_YT_BALANCE");
        IERC20 pt = IERC20(yt.PT());
        pt.transferFrom(msg.sender, address(yt), amount);
        uint256 amountScyOut = yt.redeemPY(msg.sender);
        require(amountScyOut > 0, "FUNDKEEPER_NPT_EXPIRED");
    }

    function mintMarketLP(
        PendleMarket market,
        address to,
        uint256 amount
    ) public {
        (ISuperComposableYield scy, IPPrincipalToken pt, IPYieldToken yt) = market.readTokens();

        address baseToken = scy.getTokensIn()[1];
        uint256 amountPT = mintYT(address(scy), baseToken, address(yt), 10**20);
        uint256 amountSCY = mintScySingleBase(address(scy), baseToken, 6 * 10**19);

        // mint LP
        pt.transfer(address(market), amountPT);
        scy.transfer(address(market), amountSCY);
        market.mint(address(this));
        require(market.balanceOf(address(this)) >= amount, "requesting too much lp");
        market.transfer(to, amount - 1);

        // return dust
        uint256 dust = market.balanceOf(address(this)) - 1;
        market.transfer(address(market), dust);
        market.burn(address(this), address(this));

        market.transfer(to, 1); // to update their activeBalance
    }

    function burnMarketLP(PendleMarket market, uint256 amount) public {
        market.transferFrom(msg.sender, address(market), amount);
        market.burn(address(this), address(this));
    }

    receive() external payable {}
}
