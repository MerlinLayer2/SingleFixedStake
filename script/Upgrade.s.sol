// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StakeCommon } from "../src/StakeCommon.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Upgrade is Script {
    function run() external view {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        address newImplementation = vm.envAddress("NEW_IMPLEMENTATION");
        uint256 delayDays = vm.envUint("DELAY_DAYS");
        uint256 delayApr = vm.envUint("DELAY_APR");
        require(delayDays > 0, "delay days must be positive");

        bytes memory upgradeData = abi.encodeWithSelector(
            UUPSUpgradeable.upgradeToAndCall.selector,
            newImplementation,
            abi.encodeCall(StakeCommon.initializeV2, (delayDays, delayApr))
        );

        console.log("Owner contract transaction to:", proxyAddress);
        console.log("Value: 0");
        console.log("Calldata:");
        console.logBytes(upgradeData);
    }
}
