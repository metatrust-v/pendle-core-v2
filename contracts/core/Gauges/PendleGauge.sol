// SPDX-License-Identifier: GPL-3.0-or-later

import "./EpochController.sol";
import "../../libraries/math/FixedPoint.sol";
import "../../interfaces/IVEPendleToken.sol";
import "../../interfaces/IGaugeController.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";

pragma solidity 0.8.9;
pragma abicoder v2;

contract PendleGauge is EpochController {
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant LP_CONTRIB = 40;
    uint256 public constant VEPENDLE_CONTRIB = 60;
    uint256 public constant DENOMINATOR = 100;

    IERC20 public immutable lpToken;
    IERC20 public immutable pendle;
    IVEPendleToken public immutable vePendle;
    IGaugeController public immutable controller;

    struct UserInfo {
        uint256 lpBalance;
        uint256 workingBalance;
        uint256 rewardAccrued;
        uint256 lastRewardIndex;
    }

    struct GlobalInfo {
        uint256 supplyLp;
        uint256 supplyWorking;
        uint256 rewardIndex;
        uint256 lastAccumulatedReward;
    }

    GlobalInfo public rewardInfo;
    mapping(address => UserInfo) public userInfos;

    constructor(
        IERC20 _lpToken,
        IVEPendleToken _vePendle,
        IGaugeController _controller,
        uint256 _startTime
    ) EpochController(_startTime) {
        lpToken = _lpToken;
        vePendle = _vePendle;
        controller = _controller;
        pendle = _vePendle.pendle();
    }

    function deposit(address user) external {
        UserInfo memory userRwd = _updateUserRewardIndex(user);
        uint256 amount = _consumeLpToken();
        require(amount > 0, "ZERO_AMOUNT");
        _updateUserBalance(user, userRwd.lpBalance + amount);
    }

    function withdraw(uint256 amount) external {
        address user = msg.sender;
        UserInfo memory userRwd = _updateUserRewardIndex(user);
        require(amount > 0, "ZERO_AMOUNT");
        lpToken.transfer(user, amount);
        _updateUserBalance(user, userRwd.lpBalance - amount);
    }

    function harvest() external {
        address user = msg.sender;
        UserInfo memory userRwd = _updateUserRewardIndex(user);
        if (userRwd.rewardAccrued > 0) {
            pendle.safeTransferFrom(address(controller), user, userRwd.rewardAccrued);
            userInfos[user].rewardAccrued = 0;
        }
    }

    function _updateUserBalance(address user, uint256 newBalance) internal {
        UserInfo memory userRwd = userInfos[user];
        uint256 supplyLp = lpToken.balanceOf(user);
        userRwd.lpBalance = newBalance;

        uint256 lpContrib = LP_CONTRIB * userRwd.lpBalance;
        uint256 vePendleBooster = vePendle.balanceOf(user).divUp(vePendle.totalSupply());
        uint256 vePendleContrib = VEPENDLE_CONTRIB * vePendleBooster.mulDown(supplyLp);
        userRwd.workingBalance = (lpContrib + vePendleContrib) / DENOMINATOR;
        if (userRwd.workingBalance > userRwd.lpBalance) {
            userRwd.workingBalance = userRwd.lpBalance;
        }

        userInfos[user] = userRwd;
    }

    function _consumeLpToken() internal returns (uint256) {
        uint256 currentBalance = lpToken.balanceOf(address(this));
        uint256 amount = currentBalance - rewardInfo.supplyLp;
        rewardInfo.supplyLp = amount;
        return amount;
    }

    function _updateGlobalRewardIndex() internal returns (GlobalInfo memory rwdInfo) {
        rwdInfo = rewardInfo;
        uint256 accumulatedReward = controller.accumulatedReward(address(this));
        rwdInfo.rewardIndex += (accumulatedReward - rwdInfo.lastAccumulatedReward).divUp(
            rwdInfo.supplyWorking
        );
        rwdInfo.lastAccumulatedReward = accumulatedReward;
        rewardInfo = rwdInfo;
    }

    function _updateUserRewardIndex(address user) internal returns (UserInfo memory userRwd) {
        GlobalInfo memory rwdInfo = _updateGlobalRewardIndex();
        userRwd = userInfos[user];
        userRwd.rewardAccrued += (rwdInfo.rewardIndex - userRwd.lastRewardIndex).mulDown(
            userRwd.workingBalance
        );
        userRwd.lastRewardIndex = rwdInfo.rewardIndex;
        userInfos[user] = userRwd;
    }
}
