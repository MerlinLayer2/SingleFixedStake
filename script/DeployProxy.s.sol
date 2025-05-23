// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { SingleFixedStake } from "../src/SingleFixedStake.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployProxy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address stakeToken = vm.envAddress("STAKE_TOKEN");
        address rewardsSourceAddress = vm.envAddress("REWARDS_SOURCE_ADDRESS");
        uint256 ndays = vm.envUint("NDAYS");
        uint256 apr = vm.envUint("APR");
        uint256 stakeCap = vm.envUint("STAKE_CAP");

        vm.startBroadcast(deployerPrivateKey);

        // 1. deploy implementation contract
        SingleFixedStake implementation = new SingleFixedStake();

        // 2. prepare init data
        bytes memory initData = abi.encodeWithSelector(
            SingleFixedStake.initialize.selector,
            vm.addr(deployerPrivateKey), // admin
            stakeToken,
            rewardsSourceAddress,
            ndays,
            apr,
            stakeCap
        );

        // 3. deploy proxy contract with the implementation address and init data
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        vm.stopBroadcast();

        console.log("Implementation deployed to:", address(implementation));
        console.log("Proxy deployed to:", address(proxy));
    }
}
