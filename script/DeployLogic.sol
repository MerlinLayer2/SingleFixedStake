// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Script } from "lib/forge-std/src/Script.sol";
import { console } from "forge-std/console.sol";
import { BtcStake } from "../src/BtcStake.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        BtcStake imp = new BtcStake();

        vm.stopBroadcast();

        console.log("logic deployed to:", address(imp));
    }
}
