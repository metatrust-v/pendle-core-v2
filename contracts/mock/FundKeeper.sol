pragma solidity ^0.8.0;
import "../interfaces/IQiErc20.sol";
import "../LiquidYieldToken/ILiquidYieldToken.sol";
import "../core/PendleYieldToken.sol";
import "hardhat/console.sol";

contract FundKeeper {
    constructor() {}

    function transferTo(IERC20 token, address to, uint256 amount) public {
        token.transfer(to, amount);
    }

    function transferToMany(IERC20 token, address[] calldata to, uint256 amount) public {
        for(uint8 i = 0; i < to.length; ++i) {
            require(token.balanceOf(address(this)) >= amount, "fund keeper does not have enough fund");
            token.transfer(to[i], amount);
        }
    }

    function mintLytSingleBase(address lyt, address base, uint256 amount) public {
        IERC20(base).transfer(lyt, amount);
        ILiquidYieldToken(lyt).mint(address(this), base, 0);
    }

    function mintYT(address lyt, address base, address yt, uint256 amountBase) public {
        IERC20(base).transfer(lyt, amountBase);
        uint256 lytAmount = ILiquidYieldToken(lyt).mint(address(this), base, 0);
        IERC20(lyt).transfer(yt, lytAmount);
        PendleYieldToken(yt).mintYO(address(this), address(this));
    }

    function depositBenqi(IQiErc20 qiToken, uint256 amount) public {
        IERC20 underlying = IERC20(qiToken.underlying());
        underlying.approve(address(qiToken), amount);
        qiToken.mint(amount);
        qiToken.borrow(amount / 2);
    }
}