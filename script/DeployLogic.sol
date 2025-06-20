// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Script } from "lib/forge-std/src/Script.sol";
import { console } from "forge-std/console.sol";
import {NonProfitStake} from "../src/NonProfitStake.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        NonProfitStake imp = new NonProfitStake();

        vm.stopBroadcast();

        console.log("logic deployed to:", address(imp));
    }
}
