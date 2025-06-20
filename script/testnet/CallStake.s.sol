// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

//import { Script } from "forge-std/Script.sol";
//import { console } from "forge-std/console.sol";
//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import {BtcStake} from "../../src/SimpleStake.sol";
//
//contract CallStake is Script {
//    BtcStake singleFixedStake;
//    address proxyAddress;
//    uint256 deployerPrivateKey;
//    uint32 id = 0;
//
//    function setUp() public {
//        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//        proxyAddress = vm.envAddress("PROXY_ADDRESS");
//        console.log("setUp, proxyAddress:", proxyAddress);
//
//        singleFixedStake = BtcStake(proxyAddress);
//    }
//
//    // 授权代币
//    function approve() public {
//        vm.startBroadcast(deployerPrivateKey);
//
//        // 假设我们要授权质押1个代币（需要根据代币的decimals调整）
//        uint256 amount = 1e40; // 如果代币是18位精度
//
//        address merlAddress = address(0x5C9AD13BE752a5E21e7Ed393Bb7d407144C6d550); // merl token address
//        IERC20(merlAddress).approve(proxyAddress, amount);
//
//        console.log("Approve amount:", amount);
//        vm.stopBroadcast();
//    }
//
//    // 质押代币
//    function stake() public {
//        vm.startBroadcast(deployerPrivateKey);
//
//        // 假设我们要质押1个代币（需要根据代币的decimals调整）
//        uint256 amount = 1e18; // 如果代币是18位精度
//
//        // 调用质押函数
//        singleFixedStake.stake(amount);
//
//        console.log("Staked amount:", amount);
//        vm.stopBroadcast();
//    }
//
//    function unstake() public {
//        vm.startBroadcast(deployerPrivateKey);
//
//        // 等待一段时间以累积奖励
//        vm.warp(block.timestamp + 1 days);
//        singleFixedStake.unstake(id);
//
//        console.log("unstake");
//        vm.stopBroadcast();
//    }
//
//    // 提取质押的代币和奖励
//    function withdraw() public {
//        vm.startBroadcast(deployerPrivateKey);
//
//        // 提取全部质押和奖励
//        singleFixedStake.withdraw(id);
//
//        console.log("Withdrawn all stakes and rewards");
//        vm.stopBroadcast();
//    }
//
//    function unstakeAndWithdraw() public {
//        vm.startBroadcast(deployerPrivateKey);
//
//        // 提取全部质押和奖励
//        singleFixedStake.unstakeAndWithdraw(id);
//
//        console.log("unstakeAndWithdraw ...");
//        vm.stopBroadcast();
//    }
//
//    // 获取质押信息
//    function getStakeRewards() public view {
//        vm.addr(deployerPrivateKey);
//
//        // 获取质押金额
//        uint256 totalRewards = singleFixedStake.calTotalRewards(id);
//        // 获取可提取奖励
//        uint256 currentRewards = singleFixedStake.calCurrentRewards(id);
//
//        console.log("totalRewards:", totalRewards);
//        console.log("currentRewards:", currentRewards);
//    }
//
//    // Run all operations
//    function run() public {
//        // 授权代币
//        approve();
//
//        // 质押代币
//        stake();
//
//        // 等待一段时间以累积奖励
//        vm.warp(block.timestamp + 1 days);
//
//        // 查看质押信息
//        getStakeRewards();
//
//        unstake();
//
//        withdraw();
//    }
//}
