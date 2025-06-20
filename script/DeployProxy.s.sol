// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { BtcStake } from "../src/BtcStake.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployProxy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 endTimestamp = vm.envUint("END_TIMESTAMP");
        uint256 stakeCap = vm.envUint("STAKE_CAP");

        vm.startBroadcast(deployerPrivateKey);

        // 1. deploy implementation contract
        BtcStake implementation = new BtcStake();

        // 2. prepare init data
        bytes memory initData = abi.encodeWithSelector(
            BtcStake.initialize.selector,
            vm.addr(deployerPrivateKey), // admin
            endTimestamp,
            stakeCap
        );

        // 3. deploy proxy contract with the implementation address and init data
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        vm.stopBroadcast();

        console.log("Implementation deployed to:", address(implementation));
        console.log("Proxy deployed to:", address(proxy));
    }
}
