// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./PendleBaseToken.sol";
import "../SuperComposableYield/ISuperComposableYield.sol";
import "../interfaces/IPYieldToken.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../libraries/math/FixedPoint.sol";
import "../interfaces/IPYieldContractFactory.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../SuperComposableYield/SCYUtils.sol";
import "../SuperComposableYield/implementations/RewardManager.sol";

contract PendleYieldToken is PendleBaseToken, IPYieldToken, RewardManager {
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;

    struct UserData {
        uint256 lastScyIndex;
        uint256 dueInterest;
    }

    address public immutable SCY;
    address public immutable OT;

    /// params to do interests & rewards accounting
    uint256 public lastScyBalance;
    uint256 public lastScyIndexBeforeExpiry;
    uint256[] public paramL;

    /// params to do fee accounting
    mapping(address => uint256) public totalRewardsPostExpiry;
    uint256 public totalProtocolFee;

    mapping(address => UserData) public data;

    constructor(
        address _SCY,
        address _OT,
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _expiry
    ) PendleBaseToken(_name, _symbol, __decimals, _expiry) {
        SCY = _SCY;
        OT = _OT;
    }

    /**
     * @notice this function splits scy into OT + YT of equal qty
     * @dev the scy to tokenize has to be pre-transferred to this contract prior to the function call
     */
    function mintYO(address receiverOT, address receiverYT) public returns (uint256 amountYOOut) {
        uint256 amountToTokenize = _receiveSCY();

        amountYOOut = _calcAmountToMint(amountToTokenize);

        _mint(receiverYT, amountYOOut);

        IPOwnershipToken(OT).mintByYT(receiverOT, amountYOOut);
    }

    /// this function converts YO tokens into scy, but interests & rewards are not included
    function redeemYO(address receiver) public returns (uint256 amountScyOut) {
        // minimum of OT & YT balance
        uint256 amountYOToRedeem = IERC20(OT).balanceOf(address(this));
        if (!isExpired()) {
            amountYOToRedeem = Math.min(amountYOToRedeem, balanceOf(address(this)));
            _burn(address(this), amountYOToRedeem);
        }
        IPOwnershipToken(OT).burnByYT(address(this), amountYOToRedeem);

        amountScyOut = _calcAmountRedeemable(amountYOToRedeem);

        IERC20(SCY).safeTransfer(receiver, amountScyOut);
        _afterTransferOutSCY();
    }

    function redeemDueInterest(address user) public returns (uint256 interestOut) {
        updateUserReward(user);
        _updateDueInterest(user);

        uint256 interestPreFee = data[user].dueInterest;
        data[user].dueInterest = 0;

        uint256 feeRate = IPYieldContractFactory(factory).interestFeeRate();
        uint256 feeAmount = interestPreFee.mulDown(feeRate);
        totalProtocolFee += feeAmount;

        interestOut = interestPreFee - feeAmount;
        IERC20(SCY).safeTransfer(user, interestOut);
        _afterTransferOutSCY();
    }

    function redeemDueRewards(address user, address receiver)
        public
        returns (uint256[] memory rewardsOut)
    {
        if (user != msg.sender) require(receiver == user, "invalid receiver");
        else require(receiver != address(0), "zero address");

        updateUserReward(user);
        rewardsOut = _doTransferOutRewardsForUser(user, receiver);
    }

    function updateGlobalReward() public virtual {
        address[] memory rewardTokens = getRewardTokens();
        _updateGlobalReward(rewardTokens, totalSupply());
    }

    function updateUserReward(address user) public virtual {
        uint256 scyIndex = data[user].lastScyIndex;
        uint256 impliedScyBalance = _getImpliedScyBalance(user, scyIndex);
        uint256 totalScy = IERC20(SCY).balanceOf(address(this));
        _updateUserReward(user, impliedScyBalance, totalScy);
    }

    function _updateGlobalReward(address[] memory rewardTokens, uint256 totalSupply)
        internal
        virtual
        override
    {
        _redeemExternalReward();

        _initGlobalReward(rewardTokens);

        bool _isExpired = isExpired();
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            uint256 currentRewardBalance = IERC20(token).balanceOf(address(this));
            uint256 totalIncomeReward = currentRewardBalance - globalReward[token].lastBalance;

            if (_isExpired) {
                totalRewardsPostExpiry[token] += totalIncomeReward;
            } else if (totalSupply != 0) {
                globalReward[token].index += totalIncomeReward.divDown(totalSupply);
            }

            globalReward[token].lastBalance = currentRewardBalance;
        }
    }

    function _redeemExternalReward() internal virtual override {
        ISuperComposableYield(SCY).redeemReward(address(this), address(this));
    }

    function getRewardTokens()
        public
        view
        virtual
        override(RewardManager)
        returns (address[] memory)
    {
        return ISuperComposableYield(SCY).getRewardTokens();
    }

    function getScyIndexBeforeExpiry() public returns (uint256 res) {
        if (isExpired()) return res = lastScyIndexBeforeExpiry;
        res = ISuperComposableYield(SCY).scyIndexCurrent();
        lastScyIndexBeforeExpiry = res;
    }

    function withdrawFeeToTreasury() public {
        address[] memory rewardTokens = ISuperComposableYield(SCY).getRewardTokens();
        uint256 length = rewardTokens.length;
        address treasury = IPYieldContractFactory(factory).treasury();

        for (uint256 i = 0; i < length; i++) {
            address token = rewardTokens[i];
            uint256 outAmount = totalRewardsPostExpiry[token];
            if (outAmount > 0) IERC20(rewardTokens[i]).safeTransfer(treasury, outAmount);
            totalRewardsPostExpiry[token] = 0;
        }

        if (totalProtocolFee > 0) {
            IERC20(SCY).safeTransfer(treasury, totalProtocolFee);
            _afterTransferOutSCY();
            totalProtocolFee = 0;
        }
    }

    function _updateDueInterest(address user) internal {
        uint256 prevIndex = data[user].lastScyIndex;

        uint256 currentIndex = getScyIndexBeforeExpiry();

        if (prevIndex == currentIndex) return;
        if (prevIndex == 0) {
            data[user].lastScyIndex = currentIndex;
            return;
        }

        uint256 principal = balanceOf(user);

        uint256 interestFromYT = (principal * (currentIndex - prevIndex)).divDown(
            prevIndex * currentIndex
        );

        data[user].dueInterest += interestFromYT;
        data[user].lastScyIndex = currentIndex;
    }

    function _calcAmountToMint(uint256 amount) internal returns (uint256) {
        return SCYUtils.scyToAsset(getScyIndexBeforeExpiry(), amount);
    }

    function _calcAmountRedeemable(uint256 amount) internal returns (uint256) {
        return SCYUtils.assetToScy(getScyIndexBeforeExpiry(), amount);
    }

    function _receiveSCY() internal returns (uint256 amount) {
        uint256 balanceScy = IERC20(SCY).balanceOf(address(this));
        amount = balanceScy - lastScyBalance;
        require(amount > 0, "RECEIVE_ZERO");
        lastScyBalance = balanceScy;
    }

    function _afterTransferOutSCY() internal {
        lastScyBalance = IERC20(SCY).balanceOf(address(this));
    }

    function _getImpliedScyBalance(address user, uint256 scyIndex) internal returns (uint256) {
        return SCYUtils.assetToScy(scyIndex, balanceOf(user)) + data[user].dueInterest;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        uint256 scyIndex = ISuperComposableYield(SCY).scyIndexCurrent();
        address[] memory rewardTokens = getRewardTokens();
        _updateGlobalReward(rewardTokens, IERC20(SCY).balanceOf(address(this)));

        if (from != address(0) && from != address(this)) {
            _updateDueInterest(from);
            _updateUserRewardSkipGlobal(rewardTokens, from, _getImpliedScyBalance(from, scyIndex));
        }
        if (to != address(0) && to != address(this)) {
            _updateDueInterest(to);
            _updateUserRewardSkipGlobal(rewardTokens, to, _getImpliedScyBalance(to, scyIndex));
        }
    }
}
/*INVARIANTS TO CHECK
- supply OT == supply YT
- reentrancy check
*/
