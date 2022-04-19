// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../SuperComposableYield/ISuperComposableYield.sol";
import "../SuperComposableYield/implementations/IRewardManager.sol";
import "../interfaces/IPRouterStatic.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPYieldContractFactory.sol";
import "../interfaces/IPMarketFactory.sol";
import "../libraries/math/MarketMathAux.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract RouterStatic is IPRouterStatic {
    using MarketMathCore for MarketState;
    using MarketMathAux for MarketState;
    using Math for uint256;
    using Math for int256;
    using LogExpMath for int256;

    IPYieldContractFactory public immutable yieldContractFactory;
    IPMarketFactory public immutable marketFactory;

    constructor(IPYieldContractFactory _yieldContractFactory, IPMarketFactory _marketFactory) {
        yieldContractFactory = _yieldContractFactory;
        marketFactory = _marketFactory;
    }

    function addLiquidityStatic(
        address market,
        uint256 scyDesired,
        uint256 otDesired
    )
        external
        returns (
            uint256 netLpOut,
            uint256 scyUsed,
            uint256 otUsed
        )
    {
        MarketState memory state = IPMarket(market).readState(false);
        (, netLpOut, scyUsed, otUsed) = state.addLiquidity(
            scyIndex(market),
            scyDesired,
            otDesired,
            false
        );
    }

    function removeLiquidityStatic(address market, uint256 lpToRemove)
        external
        view
        returns (uint256 netScyOut, uint256 netOtOut)
    {
        MarketState memory state = IPMarket(market).readState(false);
        (netScyOut, netOtOut) = state.removeLiquidity(lpToRemove, false);
    }

    function swapOtForScyStatic(address market, uint256 exactOtIn)
        external
        returns (uint256 netScyOut, uint256 netScyFee)
    {
        MarketState memory state = IPMarket(market).readState(false);
        (netScyOut, netScyFee) = state.swapExactOtForScy(
            scyIndex(market),
            exactOtIn,
            block.timestamp,
            false
        );
    }

    function swapScyForOtStatic(address market, uint256 exactOtOut)
        external
        returns (uint256 netScyIn, uint256 netScyFee)
    {
        MarketState memory state = IPMarket(market).readState(false);
        (netScyIn, netScyFee) = state.swapScyForExactOt(
            scyIndex(market),
            exactOtOut,
            block.timestamp,
            false
        );
    }

    function scyIndex(address market) public returns (SCYIndex index) {
        return SCYIndexLib.newIndex(IPMarket(market).SCY());
    }

    function getOtImpliedYield(address market) public view returns (int256) {
        MarketState memory state = IPMarket(market).readState(false);

        int256 lnImpliedRate = (state.lastImpliedRate).Int();
        return lnImpliedRate.exp();
    }

    function getPendleTokenType(address token)
        external
        view
        returns (
            bool isOT,
            bool isYT,
            bool isMarket
        )
    {
        if (yieldContractFactory.isOT(token)) isOT = true;
        else if (yieldContractFactory.isYT(token)) isYT = true;
        else if (marketFactory.isValidMarket(token)) isMarket = true;
    }

    function getUserYOInfo(address yo, address user)
        public
        view
        returns (UserYOInfo memory userYOInfo)
    {
        (userYOInfo.yt, userYOInfo.ot) = getYO(yo);
        IPYieldToken YT = IPYieldToken(userYOInfo.yt);
        userYOInfo.ytBalance = YT.balanceOf(user);
        userYOInfo.otBalance = IPOwnershipToken(userYOInfo.ot).balanceOf(user);
        userYOInfo.unclaimedInterest.token = YT.SCY();
        (, userYOInfo.unclaimedInterest.amount) = YT.getInterestData(user);
        address[] memory rewardTokens = YT.getRewardTokens();
        TokenAmount[] memory unclaimedRewards = new TokenAmount[](rewardTokens.length);
        uint256 length = 0;
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address rewardToken = rewardTokens[i];
            (, uint256 amount) = YT.getUserReward(user, rewardToken);
            if (amount > 0) {
                unclaimedRewards[length].token = rewardToken;
                unclaimedRewards[length].amount = amount;
                ++length;
            }
        }
        userYOInfo.unclaimedRewards = new TokenAmount[](length);
        for (uint256 i = 0; i < length; ++i) {
            userYOInfo.unclaimedRewards[i] = unclaimedRewards[i];
        }
    }

    function getYOInfo(address yo)
        external
        returns (
            uint256 exchangeRate,
            uint256 totalSupply,
            RewardIndex[] memory rewardIndexes
        )
    {
        (address yt, ) = getYO(yo);
        IPYieldToken YT = IPYieldToken(yt);
        exchangeRate = YT.getScyIndexBeforeExpiry();
        totalSupply = YT.totalSupply();
        address[] memory rewardTokens = YT.getRewardTokens();
        rewardIndexes = new RewardIndex[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address rewardToken = rewardTokens[i];
            rewardIndexes[i].rewardToken = rewardToken;
            (, rewardIndexes[i].index) = YT.getGlobalReward(rewardToken);
        }
    }

    function getYO(address yo) public view returns (address ot, address yt) {
        if (yieldContractFactory.isYT(yo)) {
            yt = yo;
            ot = IPYieldToken(yo).OT();
        } else {
            yt = IPOwnershipToken(yo).YT();
            ot = yo;
        }
    }

    function getMarketInfo(address market)
        external
        view
        returns (
            address ot,
            address scy,
            MarketState memory state,
            int256 impliedYield,
            uint256 exchangeRate
        )
    {
        IPMarket _market = IPMarket(market);
        ot = _market.OT();
        scy = _market.SCY();
        state = _market.readState(true);
        impliedYield = getOtImpliedYield(market);
        exchangeRate = 0; // TODO: get the actual exchange rate
    }

    function getUserMarketInfo(address market, address user)
        public
        view
        returns (UserMarketInfo memory userMarketInfo)
    {
        IPMarket _market = IPMarket(market);
        userMarketInfo.market = market;
        userMarketInfo.lpBalance = _market.balanceOf(user);
        // TODO: Is there a way to convert LP to OT and SCY?
        userMarketInfo.otBalance = TokenAmount(_market.OT(), 0);
        userMarketInfo.scyBalance = TokenAmount(_market.SCY(), 0);
        // TODO: Get this from SCY once it is in the interface
        userMarketInfo.assetBalance = TokenAmount(address(0), 0);
    }

    function getUserYOPositionsByYOs(address user, address[] calldata yos)
        external
        view
        returns (UserYOInfo[] memory userYOPositions)
    {
        userYOPositions = new UserYOInfo[](yos.length);
        for (uint256 i = 0; i < yos.length; ++i) {
            userYOPositions[i] = getUserYOInfo(yos[i], user);
        }
    }

    function getUserMarketPositions(address user, address[] calldata markets)
        external
        view
        returns (UserMarketInfo[] memory userMarketPositions)
    {
        userMarketPositions = new UserMarketInfo[](markets.length);
        for (uint256 i = 0; i < markets.length; ++i) {
            userMarketPositions[i] = getUserMarketInfo(markets[i], user);
        }
    }

    function hasYOPosition(UserYOInfo memory userYOInfo) public pure returns (bool hasPosition) {
        hasPosition = (userYOInfo.ytBalance > 0 ||
            userYOInfo.otBalance > 0 ||
            userYOInfo.unclaimedInterest.amount > 0 ||
            userYOInfo.unclaimedRewards.length > 0);
    }

    function getUserSCYInfo(address scy, address user)
        external
        view
        returns (uint256 balance, TokenAmount[] memory rewards)
    {
        ISuperComposableYield SCY = ISuperComposableYield(scy);
        balance = SCY.balanceOf(scy);
        address[] memory rewardTokens = SCY.getRewardTokens();
        rewards = new TokenAmount[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address rewardToken = rewardTokens[i];
            rewards[i].token = rewardToken;
            (, rewards[i].amount) = IRewardManager(scy).getUserReward(user, rewardToken);
        }
    }
}
