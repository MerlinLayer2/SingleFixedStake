// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Script } from "lib/forge-std/src/Script.sol";
import { console } from "forge-std/console.sol";
import { SingleFixedStake } from "../src/SingleFixedStake.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        SingleFixedStake implementation = new SingleFixedStake();

        vm.stopBroadcast();

        console.log("Implementation deployed to:", address(implementation));
    }
}
