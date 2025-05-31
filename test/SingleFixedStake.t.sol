// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { SingleFixedStake } from "../src/SingleFixedStake.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SingleFixedStakeTest is Test {
    SingleFixedStake public singleFixedStake;
    MockERC20 public stakeToken;
    
    address public admin = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public rewardsSource = address(4);
    
    uint256 public constant NDAYS = 180;
    uint256 public constant APR = 450_000; // 45%
    uint256 public constant STAKE_CAP = 2.1e27;
    uint256 public constant MIN_AMOUNT = 1e14;
    
    function setUp() public {
        // 部署代币合约
        stakeToken = new MockERC20("Stake Token", "STK");
        
        // 部署实现合约
        SingleFixedStake implementation = new SingleFixedStake();
        
        // 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            SingleFixedStake.initialize.selector,
            admin,
            address(stakeToken),
            rewardsSource,
            NDAYS,
            APR,
            STAKE_CAP
        );
        
        // 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        singleFixedStake = SingleFixedStake(address(proxy));
        
        // 给测试用户铸造代币
        stakeToken.mint(user1, 1000e18);
        stakeToken.mint(user2, 1000e18);
        // 给奖励源地址铸造代币用于发放奖励
        stakeToken.mint(rewardsSource, 1000e18);
        
        // 授权奖励源
        vm.prank(rewardsSource);
        stakeToken.approve(address(singleFixedStake), type(uint256).max);
    }
    
    function test_Initialize() public view {  // 添加 view 修饰符
        assertEq(singleFixedStake.owner(), admin);
        assertEq(address(singleFixedStake.stakeToken()), address(stakeToken));
        assertEq(singleFixedStake.rewardsSourceAddress(), rewardsSource);
        assertEq(singleFixedStake.ndays(), NDAYS);
        assertEq(singleFixedStake.apr(), APR);
        assertEq(singleFixedStake.stakeCap(), STAKE_CAP);
    }
    
    function test_Stake() public {
        uint256 stakeAmount = 100e18;
        
        vm.startPrank(user1);
        // 检查代币精度
        assertEq(stakeToken.decimals(), 18, "Token decimals should be 18");
        
        // 检查用户初始余额
        assertEq(stakeToken.balanceOf(user1), 1000e18, "Initial balance should be correct");
        
        stakeToken.approve(address(singleFixedStake), stakeAmount);
        
        uint256 beforeBalance = stakeToken.balanceOf(user1);
        singleFixedStake.stake(stakeAmount);
        uint256 afterBalance = stakeToken.balanceOf(user1);
        
        // 检查余额变化
        assertEq(beforeBalance - afterBalance, stakeAmount, "Balance change should match stake amount");
        assertEq(singleFixedStake.totalStakeAmount(), stakeAmount, "Total stake amount should match");
        
        // 验证质押信息
        (
            address account,
            uint32 id,
            uint32 startTimestamp,
            uint32 endTimestamp,
            ,
            ,
            ,
            uint256 amount,
            ,
        ) = singleFixedStake.stakes(0);
        
        assertEq(account, user1, "Stake account should be user1");
        assertEq(id, 0, "Stake ID should be 0");
        assertEq(startTimestamp, block.timestamp, "Start timestamp should be current block");
        assertEq(endTimestamp, block.timestamp + NDAYS * 1 days, "End timestamp should be correct");
        assertEq(amount, stakeAmount, "Stake amount should match input amount");
        
        vm.stopPrank();
    }

    function test_Unstake() public {
        // 先质押
        uint256 stakeAmount = 100e18;
        vm.startPrank(user1);
        stakeToken.approve(address(singleFixedStake), stakeAmount);
        singleFixedStake.stake(stakeAmount);
        
        // 等待到期时间
        skip(NDAYS * 1 days);  // 修改：等待完整的锁定期
        
        // 解除质押
        singleFixedStake.unstake(0);
        
        // 验证质押状态
        (,,,, uint32 unstakeTimestamp,,,,,) = singleFixedStake.stakes(0);
        assertEq(unstakeTimestamp, block.timestamp);
        
        vm.stopPrank();
    }
    
    function test_WithdrawRewards() public {
        // 先质押
        uint256 stakeAmount = 100e18;
        vm.startPrank(user1);
        stakeToken.approve(address(singleFixedStake), stakeAmount);
        singleFixedStake.stake(stakeAmount);
        
        // 等待到期时间并解除质押
        skip(NDAYS * 1 days);  // 修改：等待完整的锁定期
        singleFixedStake.unstake(0);
        
        // 提取奖励
        uint256 beforeBalance = stakeToken.balanceOf(user1);
        singleFixedStake.withdraw(0);
        uint256 afterBalance = stakeToken.balanceOf(user1);
        
        // 验证提取的金额包含本金和奖励
        assertTrue(afterBalance - beforeBalance > 0);
        
        vm.stopPrank();
    }
    
    function test_CalRewards() public {
        // 先质押
        uint256 stakeAmount = 100e18;
        vm.startPrank(user1);
        stakeToken.approve(address(singleFixedStake), stakeAmount);
        singleFixedStake.stake(stakeAmount);
        
        // 等待30天
        skip(30 days);
        
        // 计算应得奖励
        uint256 expectedRewards = (stakeAmount * APR * 30) / (365 * 1e6);
        uint256 actualRewards = singleFixedStake.calCurrentRewards(0);
        
        assertEq(actualRewards, expectedRewards);
        
        vm.stopPrank();
    }

    function test_GetUserTotalStakeAmount() public {
        uint256 stakeAmount = 100e18;
        vm.startPrank(user1);
        stakeToken.approve(address(singleFixedStake), stakeAmount);
        singleFixedStake.stake(stakeAmount);

        uint256 totalStakeAmount = singleFixedStake.getUserTotalStakeAmount(
            user1
        );
        assertEq(totalStakeAmount, stakeAmount);

        vm.stopPrank();
    }
}