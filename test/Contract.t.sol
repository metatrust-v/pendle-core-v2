// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/core/YieldContracts/PendleYieldContractFactory.sol";
import "../contracts/periphery/PendleGovernanceManager.sol";
import "../contracts/core/YieldContracts/PendleYieldToken.sol";
import "../contracts/mock/FundKeeper.sol";
import "../contracts/mock/ERC20Premined.sol";
import "../contracts/mock/BENQI-Smart-Contracts/Comptroller.sol";
import "../contracts/mock/BENQI-Smart-Contracts/JumpRateModel.sol";
import "../contracts/mock/BENQI-Smart-Contracts/QiErc20Delegate.sol";
import "../contracts/mock/BENQI-Smart-Contracts/QiErc20Delegator.sol";
import "../contracts/mock/BENQI-Smart-Contracts/QiAvax.sol";
import "../contracts/mock/BENQI-Smart-Contracts/Chainlink/BenqiChainlinkOracle.sol";
import "../contracts/mock/MockBenqiFeed.sol";
import "../contracts/SuperComposableYield/SCY-implementations/BenQi/PendleQiTokenSCY.sol";

contract ContractTest is Test {
    struct Env {
        FundKeeper fundKeeper;
        FundKeeper treasury;
        PendleGovernanceManager governanceManager;
        ERC20 PENDLE;
        ERC20 USD;
        address deployer;
        PendleQiTokenSCY scy;
        PendleQiTokenSCY scyAvax;
    }

    Env public env;
    address public constant WNATIVE = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;

    function clearFund(
        Env memory env,
        address[] memory from,
        address[] memory tokens
    ) public {
        for (uint256 i = 0; i < from.length; i++) {
            for (uint256 j = 0; j < tokens.length; j++) {
                address wallet = from[i];
                ERC20 token = ERC20(tokens[j]);

                uint256 bal = token.balanceOf(wallet);
                if (bal == 0) continue;

                vm.prank(wallet);
                token.transfer(address(env.fundKeeper), bal);
            }
        }
    }

    function transferNative(
        address from,
        address to,
        uint256 amount
    ) public {
        vm.prank(from);
        payable(to).transfer(amount);
    }

    function approveAll(address token, address to) public {
        ERC20 token = ERC20(token);
        token.approve(to, type(uint256).max);
    }

    function makeArr(address a1) public returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = a1;
        return arr;
    }

    function makeArr(address a1, address a2) public returns (address[] memory) {
        address[] memory arr = new address[](2);
        arr[0] = a1;
        arr[1] = a2;
        return arr;
    }

    function commonFixture() public {
        env.deployer = address(this);
        env.fundKeeper = new FundKeeper();
        env.treasury = new FundKeeper();
        env.governanceManager = new PendleGovernanceManager(env.deployer);
        env.PENDLE = new ERC20Premined("PENDLE", 18);
        vm.deal(address(env.fundKeeper), type(uint256).max);

        env.USD = new ERC20Premined("USD", 6);

        clearFund(env, makeArr(env.deployer), makeArr(address(env.USD), address(env.PENDLE)));
    }

    function deployBenQi() public {
        Comptroller comptrollerImplementation = new Comptroller();
        Unitroller unitroller = new Unitroller();
        unitroller._setPendingImplementation(address(comptrollerImplementation));
        comptrollerImplementation._become(unitroller);

        Comptroller comptroller = Comptroller(payable(unitroller));
        ERC20 qiToken = new ERC20Premined("Qi", 18);
        comptroller.setQiAddress(address(qiToken));
        qiToken.transfer(address(comptroller), qiToken.balanceOf(env.deployer));
        transferNative(env.deployer, address(comptroller), 1e28);

        // DEPLOY TOKEN
        JumpRateModel interestRateModel = new JumpRateModel(
            10**16 * 2,
            10**17,
            10**16 * 109,
            10**17 * 8
        );

        QiErc20Delegate qiErc20Implementation = new QiErc20Delegate();
        QiErc20Delegator qiUSD = new QiErc20Delegator(
            address(env.USD),
            comptroller,
            interestRateModel,
            1e18,
            "qiUSD",
            "qiUSD",
            8,
            payable(env.deployer),
            address(qiErc20Implementation),
            hex""
        );
        QiAvax qiAvax = new QiAvax(
            comptroller,
            interestRateModel,
            1e18,
            "qiAVAX",
            "qiAVAX",
            8,
            payable(env.deployer)
        );
        approveAll(address(env.USD), address(qiUSD));

        //   // SET UP TOKEN
        comptroller._supportMarket(QiToken(address(qiUSD)));
        comptroller._supportMarket(QiToken(address(qiAvax)));
        BenqiChainlinkOracle oracle = new BenqiChainlinkOracle();

        oracle.setUnderlyingPrice(QiToken(address(qiUSD)), 1e18);
        MockBenqiFeed feedAVAX = new MockBenqiFeed(1e18 * 2000);
        oracle.setFeed("qiAVAX", address(feedAVAX));

        comptroller._setPriceOracle(oracle);
        comptroller._setCollateralFactor(QiToken(address(qiUSD)), (1e18 * 8) / 10);
        comptroller._setCollateralFactor(QiToken(address(qiAvax)), (1e18 * 6) / 10);
        comptroller._setRewardSpeed(0, QiToken(address(qiUSD)), 1e18);
        comptroller._setRewardSpeed(1, QiToken(address(qiUSD)), 1e18);
        comptroller._setRewardSpeed(0, QiToken(address(qiAvax)), 1e18);
        comptroller._setRewardSpeed(1, QiToken(address(qiAvax)), 1e18);

        //   // FAKE AMOUNT
        env.fundKeeper.depositBenqi(IQiTokenTest(address(qiUSD)), 10**10);
        env.fundKeeper.depositBenqiAVAX{ value: 10**20 }(address(qiAvax), 10**20);

        //   // Deploy SCY
        env.scy = new PendleQiTokenSCY(
            "SCY-qiUSD",
            "SCY-qiUSD",
            address(qiUSD),
            false,
            WNATIVE,
            qiUSD.exchangeRateStored()
        );

        env.scyAvax = new PendleQiTokenSCY(
            "SCY-qiAVAX",
            "SCY-qiAVAX",
            address(qiAvax),
            true,
            WNATIVE,
            qiAvax.exchangeRateStored()
        );

        env.fundKeeper.mintScySingleBase(address(env.scy), address(env.scy.underlying()), 1e12);
    }

    function deployPY() {
        uint256 divisor = 1 days;
        uint256 expiry = block.timestamp + 180 days;
        expiry += divisor - (expiry % divisor);
        uint256 fee = 10**15;
        PendleYieldContractFactory factory = new PendleYieldContractFactory(
            uint96(divisor),
            uint128(fee),
            uint128(fee),
            address(env.treasury),
            address(env.governanceManager)
        );

        factory.initialize(type(PendleYieldToken).creationCode);
        (address PTaddr, address YTaddr) = factory.createYieldContract(
            address(env.scy),
            uint32(expiry)
        );
        PendleYieldToken yt = PendleYieldToken(YTaddr);
        PendlePrincipalToken ot = PendlePrincipalToken(PTaddr);
    }

    function setUp() public {
        commonFixture();
        deployBenQi();
        deployPY();
    }

    function testExample() public {}
}
