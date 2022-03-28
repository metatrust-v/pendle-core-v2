pragma solidity ^0.8.0;
import "../interfaces/IQiErc20.sol";

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

    function depositBenqi(IQiErc20 qiToken, uint256 amount) public {
        IERC20 underlying = IERC20(qiToken.underlying());
        underlying.approve(address(qiToken), amount);
        qiToken.mint(amount);
        qiToken.borrow(amount / 2);
    }
}