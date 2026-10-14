// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { SingleFixedStake } from "../src/SingleFixedStake.sol";
import { StakeCommon } from "../src/StakeCommon.sol";

contract SingleFixedStakeV2ForkTest is Test {
    address internal constant MAINNET_PROXY = 0x63B824D5D5003F49F6A06750b2cD4D8c5972478e;

    function test_UpgradeExistingMerlinProxy() public {
        string memory rpcUrl = vm.envOr("MERLIN_FORK_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            vm.skip(true, "MERLIN_FORK_URL not set");
            return;
        }

        vm.createSelectFork(rpcUrl);
        SingleFixedStake proxy = SingleFixedStake(MAINNET_PROXY);
        address oldImplementation = address(uint160(uint256(vm.load(MAINNET_PROXY, ERC1967Utils.IMPLEMENTATION_SLOT))));
        address oldOwner = proxy.owner();
        address oldToken = proxy.stakeToken();
        address oldRewardsSource = proxy.rewardsSourceAddress();
        uint256 oldApr = proxy.apr();
        uint256 oldStakeCap = proxy.stakeCap();
        uint256 oldTotalStakeAmount = proxy.totalStakeAmount();
        uint32 oldNextStakeId = proxy.nextStakeId();

        assertEq(oldImplementation, 0x9a0a80Eddb5B15A1DB558D1c53ba7b4C61360295);
        assertGt(oldNextStakeId, 0);
        (,,,,,,,, uint256 oldFirstReward,) = proxy.stakes(0);

        SingleFixedStake newImplementation = new SingleFixedStake();
        vm.prank(oldOwner);
        proxy.upgradeToAndCall(
            address(newImplementation), abi.encodeCall(StakeCommon.initializeV2, (uint256(90), uint256(150_000)))
        );

        assertEq(
            address(uint160(uint256(vm.load(MAINNET_PROXY, ERC1967Utils.IMPLEMENTATION_SLOT)))),
            address(newImplementation)
        );
        assertEq(proxy.owner(), oldOwner);
        assertEq(proxy.stakeToken(), oldToken);
        assertEq(proxy.rewardsSourceAddress(), oldRewardsSource);
        assertEq(proxy.apr(), oldApr);
        assertEq(proxy.stakeCap(), oldStakeCap);
        assertEq(proxy.totalStakeAmount(), oldTotalStakeAmount);
        assertEq(proxy.nextStakeId(), oldNextStakeId);
        assertEq(proxy.calTotalRewards(0), oldFirstReward);
        assertEq(proxy.delayDays(), 90);
        assertEq(proxy.delayApr(), 150_000);
    }
}
