pragma solidity ^0.8.0;
import "../interfaces/IQiErc20.sol";

contract ProtocolFakeUser {
    constructor() {}

    function depositBenqi(IQiErc20 qiToken, uint256 amount) public {
        IERC20 underlying = IERC20(qiToken.underlying());
        underlying.approve(address(qiToken), amount);
        qiToken.mint(amount);
        qiToken.borrow(amount / 2);
    }
}