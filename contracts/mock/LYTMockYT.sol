// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../LiquidYieldToken/implementations/LYTBaseWithRewards.sol";
import "../interfaces/IWETH.sol";
import "../core/PendleYieldToken.sol";
import "hardhat/console.sol";

contract PendleYTLYTBenqi is LYTBaseWithRewards {
    using SafeERC20 for IERC20;
  
    address public immutable QI;
    address public immutable WAVAX;
    address public immutable lyt;
    address public immutable yieldToken;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __lytdecimals,
        uint8 __assetDecimals,
        address _lyt,
        address _yieldToken,
        address _QI,
        address _WAVAX
    ) LYTBaseWithRewards(_name, _symbol, __lytdecimals, __assetDecimals) {
        lyt = _lyt;
        WAVAX = _WAVAX;
        QI = _QI;
        yieldToken = _yieldToken;
    }

    receive() external payable {}

    function _deposit(address token, uint256 amountBase)
        internal
        virtual
        override
        returns (uint256 amountLytOut)
    {
        if (token == lyt) {
            IERC20(lyt).transfer(yieldToken, amountBase);
            _afterSendToken(lyt);
            amountLytOut = PendleYieldToken(yieldToken).mintYO(address(this), address(this));
        } else {
            amountLytOut = amountBase;
        }
    }

    function _redeem(address token, uint256 amountLyt)
        internal
        virtual
        override
        returns (uint256 amountBaseOut)
    {
        if (token == lyt) {
            address ot = PendleYieldToken(yieldToken).OT();
            IERC20(yieldToken).transfer(yieldToken, amountLyt);
            IERC20(ot).transfer(yieldToken, amountLyt);
            _afterSendToken(yieldToken);
            _afterSendToken(ot);
            amountBaseOut = PendleYieldToken(yieldToken).redeemYO(address(this));
        } else {
            amountBaseOut = amountLyt;
        }
    }

    function lytIndexCurrent() public virtual override returns (uint256 res) {
        res = LYTBase(lyt).lytIndexCurrent();
    }

    function lytIndexStored() public view override returns (uint256 res) {
        res = LYTBase(lyt).lytIndexStored();
    }

    function getRewardTokens() public view override returns (address[] memory res) {
        res = new address[](2);
        res[0] = QI;
        res[1] = WAVAX;
    }

    function getBaseTokens() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = yieldToken;
        res[1] = lyt;
    }

    function isValidBaseToken(address token) public view virtual override returns (bool res) {
        res = (token == yieldToken || token == lyt);
    }

    function _redeemExternalReward() internal override {
        PendleYieldToken(yieldToken).redeemDueRewards(address(this));
    }
}