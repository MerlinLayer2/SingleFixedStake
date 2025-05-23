// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { SingleFixedStake } from "../src/SingleFixedStake.sol";

contract Upgrade is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // 1. deploy new implementation contract
        SingleFixedStake newImplementation = new SingleFixedStake();

        // 2. upgrade proxy
        SingleFixedStake proxy = SingleFixedStake(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");

        vm.stopBroadcast();

        console.log("New implementation deployed to:", address(newImplementation));
        console.log("Proxy upgraded successfully");
    }
}
