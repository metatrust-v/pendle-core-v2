// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../SuperComposableYield/implementations/SCYBaseWithRewards.sol";
import "../../interfaces/IQiErc20.sol";
import "../../interfaces/IBenQiComptroller.sol";
import "../../interfaces/IWETH.sol";

contract PendleBenQiErc20SCY is SCYBase {
    using SafeERC20 for IERC20;

    address public immutable underlying;
    address public immutable QI;
    address public immutable WAVAX;
    address public immutable comptroller;
    address public immutable qiToken;

    uint256 public override scyIndexStored;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __scydecimals,
        uint8 __assetDecimals,
        address _underlying,
        address _qiToken,
        address _comptroller,
        address _QI,
        address _WAVAX
    ) SCYBase(_name, _symbol, __scydecimals, __assetDecimals) {
        require(
            _qiToken != address(0) &&
                _QI != address(0) &&
                _WAVAX != address(0) &&
                _comptroller != address(0),
            "zero address"
        );
        qiToken = _qiToken;
        QI = _QI;
        WAVAX = _WAVAX;
        comptroller = _comptroller;
        underlying = _underlying;
        IERC20(underlying).safeIncreaseAllowance(qiToken, type(uint256).max);
    }

    // solhint-disable no-empty-blocks
    receive() external payable {}

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address token, uint256 amountBase)
        internal
        virtual
        override
        returns (uint256 amountScyOut)
    {
        // qiToken -> scy is 1:1
        if (token == qiToken) {
            amountScyOut = amountBase;
        } else {
            uint256 errCode = IQiErc20(qiToken).mint(amountBase);
            require(errCode == 0, "mint failed");
            _afterSendToken(underlying);
            amountScyOut = _afterReceiveToken(qiToken);
        }
    }

    function _redeem(address token, uint256 amountScy)
        internal
        virtual
        override
        returns (uint256 amountBaseOut)
    {
        if (token == qiToken) {
            amountBaseOut = amountScy;
        } else {
            // must be underlying
            uint256 errCode = IQiErc20(qiToken).redeem(amountScy);
            require(errCode == 0, "redeem failed");
            _afterSendToken(qiToken);
            amountBaseOut = _afterReceiveToken(underlying);
        }
    }

    /*///////////////////////////////////////////////////////////////
                               SCY-INDEX
    //////////////////////////////////////////////////////////////*/

    function scyIndexCurrent() public virtual override returns (uint256) {
        scyIndexStored = IQiToken(qiToken).exchangeRateCurrent();
        emit UpdateScyIndex(scyIndexStored);
        return scyIndexStored;
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function getBaseTokens() public view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = qiToken;
        res[1] = underlying;
    }

    function isValidBaseToken(address token) public view virtual override returns (bool) {
        return token == underlying || token == qiToken;
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/
    //solhint-disable-next-line no-empty-blocks
    function redeemReward(address user) public virtual override returns (uint256[] memory) {}

    //solhint-disable-next-line no-empty-blocks
    function updateGlobalReward() public virtual override {}

    //solhint-disable-next-line no-empty-blocks
    function updateUserReward(address user) public virtual override {}

    function getRewardTokens() public view virtual returns (address[] memory res) {
        res = new address[](0);
    }

    //solhint-disable-next-line no-empty-blocks
    function _redeemExternalReward() internal virtual {}
}
