// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SingleFixedStake } from "../src/SingleFixedStake.sol";
import { StakeCommon } from "../src/StakeCommon.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

contract LegacyStateHarness is SingleFixedStake {
    function seedWithdrawnRewards(uint32 id, uint256 amount) external {
        stakes[id].withdrawnRewards = amount;
    }

    function seedUnstaked(uint32 id) external {
        StakeItem storage item = stakes[id];
        totalStakeAmount -= item.amount;
        userStakeAmount[item.account] -= item.amount;
        item.unstakeTimestamp = uint32(block.timestamp);
        IERC20(stakeToken).transfer(item.account, item.amount);
    }
}

contract SingleFixedStakeV2Test is Test {
    LegacyStateHarness internal stakeContract;
    MockERC20 internal token;

    address internal constant ADMIN = address(0xA11CE);
    address internal constant USER = address(0xB0B);
    address internal constant REWARDS = address(0xCAFE);
    uint256 internal constant AMOUNT = 100e18;
    uint256 internal constant OLD_APR = 450_000;
    uint256 internal constant DELAY_APR = 150_000;
    uint256 internal constant STAKE_DAYS = 180;
    uint256 internal constant DELAY_DAYS = 90;

    function setUp() public {
        token = new MockERC20("Stake Token", "STK");
        LegacyStateHarness implementation = new LegacyStateHarness();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(
                SingleFixedStake.initialize, (ADMIN, address(token), REWARDS, STAKE_DAYS, OLD_APR, 1_000_000e18)
            )
        );
        stakeContract = LegacyStateHarness(address(proxy));
        vm.prank(ADMIN);
        stakeContract.initializeV2(DELAY_DAYS, DELAY_APR);

        token.mint(USER, 1000e18);
        token.mint(REWARDS, 1000e18);
        vm.prank(USER);
        token.approve(address(stakeContract), type(uint256).max);
        vm.prank(REWARDS);
        token.approve(address(stakeContract), type(uint256).max);
    }

    function _stake() internal returns (uint32 id) {
        id = stakeContract.nextStakeId();
        vm.prank(USER);
        stakeContract.stake(AMOUNT);
    }

    function _reward(uint256 aprValue) internal pure returns (uint256) {
        return (AMOUNT * aprValue * STAKE_DAYS) / 365 / 1e6;
    }

    function _delayReward(uint256 delayedAmount) internal pure returns (uint256) {
        return (delayedAmount * DELAY_APR * DELAY_DAYS) / 365 / 1e6;
    }

    function _principalDelayReward() internal pure returns (uint256) {
        return _delayReward(AMOUNT);
    }

    function _rewardDelayReward() internal pure returns (uint256) {
        return _delayReward(_reward(OLD_APR));
    }

    function test_AprChangeOnlyAffectsNewStakes() public {
        uint32 oldId = _stake();
        vm.prank(ADMIN);
        stakeContract.updateApr(150_000);
        uint32 newId = _stake();

        assertEq(stakeContract.calTotalRewards(oldId), _reward(OLD_APR));
        assertEq(stakeContract.calTotalRewards(newId), _reward(150_000));

        skip(30 days);
        assertEq(stakeContract.calCurrentRewards(oldId), _reward(OLD_APR) * 30 / STAKE_DAYS);
        assertEq(stakeContract.calCurrentRewards(newId), _reward(150_000) * 30 / STAKE_DAYS);

        skip((STAKE_DAYS - 30) * 1 days);
        vm.prank(USER);
        stakeContract.withdraw(oldId);
        skip(DELAY_DAYS * 1 days);
        uint256 beforeBalance = token.balanceOf(USER);
        vm.prank(USER);
        stakeContract.withdraw(oldId);
        assertEq(token.balanceOf(USER) - beforeBalance, _reward(OLD_APR) + _rewardDelayReward());
    }

    function test_EarlyWithdrawIsBlocked() public {
        uint32 id = _stake();
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(StakeCommon.NotDueYet.selector, id));
        stakeContract.withdraw(id);
    }

    function test_PrincipalAndRewardDelaysAreIndependent() public {
        uint32 id = _stake();
        skip(STAKE_DAYS * 1 days);

        vm.prank(USER);
        stakeContract.unstake(id);
        (uint256 principalStart, uint256 principalEnd, uint256 principalReward,,) = stakeContract.principalDelays(id);
        assertEq(principalStart, block.timestamp);
        assertEq(principalEnd, principalStart + DELAY_DAYS * 1 days);
        assertEq(principalReward, _principalDelayReward());
        (uint256 rewardStart,,,,) = stakeContract.rewardDelays(id);
        assertEq(rewardStart, 0);
        assertEq(token.balanceOf(USER), 900e18);
        assertEq(stakeContract.totalStakeAmount(), AMOUNT);

        skip(30 days);
        vm.prank(USER);
        stakeContract.withdraw(id);
        (uint256 laterRewardStart, uint256 rewardEnd, uint256 rewardDelayReward,,) = stakeContract.rewardDelays(id);
        rewardStart = laterRewardStart;
        assertEq(rewardStart, block.timestamp);
        assertEq(rewardEnd, rewardStart + DELAY_DAYS * 1 days);
        assertEq(rewardDelayReward, _rewardDelayReward());

        vm.startPrank(ADMIN);
        stakeContract.updateDelayDays(30);
        stakeContract.updateDelayApr(0);
        vm.stopPrank();
        (,, uint256 lockedPrincipalReward,,) = stakeContract.principalDelays(id);
        (,, uint256 lockedRewardDelayReward,,) = stakeContract.rewardDelays(id);
        assertEq(lockedPrincipalReward, _principalDelayReward());
        assertEq(lockedRewardDelayReward, _rewardDelayReward());

        skip((DELAY_DAYS - 30) * 1 days);
        uint256 beforePrincipal = token.balanceOf(USER);
        vm.prank(USER);
        stakeContract.unstake(id);
        assertEq(token.balanceOf(USER) - beforePrincipal, AMOUNT + _principalDelayReward());
        assertEq(stakeContract.totalStakeAmount(), 0);

        vm.prank(USER);
        stakeContract.withdraw(id);
        (uint256 unchangedRewardStart, uint256 unchangedRewardEnd,,,) = stakeContract.rewardDelays(id);
        assertEq(unchangedRewardStart, rewardStart);
        assertEq(unchangedRewardEnd, rewardEnd);
        assertEq(token.balanceOf(USER), beforePrincipal + AMOUNT + _principalDelayReward());

        skip(30 days);
        uint256 beforeRewards = token.balanceOf(USER);
        vm.prank(USER);
        stakeContract.withdraw(id);
        assertEq(token.balanceOf(USER) - beforeRewards, _reward(OLD_APR) + _rewardDelayReward());

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(StakeCommon.AlreadyWithdrawn.selector, id));
        stakeContract.withdraw(id);
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(StakeCommon.AlreadyUnstaked.selector, id));
        stakeContract.unstake(id);
    }

    function test_RewardDelayDoesNotStartPrincipalDelay() public {
        uint32 id = _stake();
        skip(STAKE_DAYS * 1 days);
        vm.prank(USER);
        stakeContract.withdraw(id);
        skip(DELAY_DAYS * 1 days);

        vm.prank(USER);
        stakeContract.unstake(id);
        assertEq(token.balanceOf(USER), 900e18);
        vm.prank(USER);
        stakeContract.withdraw(id);
        assertEq(token.balanceOf(USER), 900e18 + _reward(OLD_APR) + _rewardDelayReward());
        skip(DELAY_DAYS * 1 days);
        vm.prank(USER);
        stakeContract.unstake(id);
        assertEq(token.balanceOf(USER), 1000e18 + _reward(OLD_APR) + _rewardDelayReward() + _principalDelayReward());
    }

    function test_CombinedClaimStartsBothDelays() public {
        uint32 id = _stake();
        skip(STAKE_DAYS * 1 days);
        vm.prank(USER);
        stakeContract.unstakeAndWithdraw(id);
        assertEq(token.balanceOf(USER), 900e18);
        (uint256 principalStart,,,,) = stakeContract.principalDelays(id);
        (uint256 rewardStart,,,,) = stakeContract.rewardDelays(id);
        assertEq(principalStart, rewardStart);
        skip(DELAY_DAYS * 1 days);
        vm.prank(USER);
        stakeContract.unstakeAndWithdraw(id);
        assertEq(token.balanceOf(USER), 1000e18 + _reward(OLD_APR) + _principalDelayReward() + _rewardDelayReward());
    }

    function test_CombinedClaimHandlesDifferentMaturities() public {
        uint32 id = _stake();
        skip(STAKE_DAYS * 1 days);
        vm.prank(USER);
        stakeContract.unstake(id);
        skip(30 days);
        vm.prank(USER);
        stakeContract.unstakeAndWithdraw(id);

        skip((DELAY_DAYS - 30) * 1 days);
        vm.prank(USER);
        stakeContract.unstakeAndWithdraw(id);
        assertEq(token.balanceOf(USER), 1000e18 + _principalDelayReward());
        (,,,,,,,,, uint256 withdrawnRewards) = stakeContract.stakes(id);
        assertEq(withdrawnRewards, 0);

        skip(30 days);
        vm.prank(USER);
        stakeContract.unstakeAndWithdraw(id);
        assertEq(token.balanceOf(USER), 1000e18 + _principalDelayReward() + _reward(OLD_APR) + _rewardDelayReward());
    }

    function test_OldPartialRewardOnlyPaysRemainingAmount() public {
        uint32 id = _stake();
        uint256 alreadyPaid = _reward(OLD_APR) / 3;
        stakeContract.seedWithdrawnRewards(id, alreadyPaid);
        skip(STAKE_DAYS * 1 days);
        vm.prank(USER);
        stakeContract.withdraw(id);
        skip(DELAY_DAYS * 1 days);

        uint256 beforeBalance = token.balanceOf(USER);
        vm.prank(USER);
        stakeContract.withdraw(id);
        assertEq(
            token.balanceOf(USER) - beforeBalance,
            _reward(OLD_APR) - alreadyPaid + _delayReward(_reward(OLD_APR) - alreadyPaid)
        );
    }

    function test_OldUnstakedPositionEarnsDelayRewardOnUnpaidRewards() public {
        uint32 id = _stake();
        skip(STAKE_DAYS * 1 days);
        stakeContract.seedUnstaked(id);
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(StakeCommon.AlreadyUnstaked.selector, id));
        stakeContract.unstake(id);
        vm.prank(USER);
        stakeContract.withdraw(id);
        (,, uint256 delayReward,,) = stakeContract.rewardDelays(id);
        assertEq(delayReward, _delayReward(_reward(OLD_APR)));
        skip(DELAY_DAYS * 1 days);
        uint256 beforeBalance = token.balanceOf(USER);
        vm.prank(USER);
        stakeContract.withdraw(id);
        assertEq(token.balanceOf(USER) - beforeBalance, _reward(OLD_APR) + _rewardDelayReward());
    }

    function test_OldFullyWithdrawnRewardOnlyStartsPrincipalDelay() public {
        uint32 id = _stake();
        stakeContract.seedWithdrawnRewards(id, _reward(OLD_APR));
        skip(STAKE_DAYS * 1 days);
        vm.prank(USER);
        stakeContract.unstake(id);
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(StakeCommon.AlreadyWithdrawn.selector, id));
        stakeContract.withdraw(id);
        skip(DELAY_DAYS * 1 days);
        uint256 beforeBalance = token.balanceOf(USER);
        vm.prank(USER);
        stakeContract.unstake(id);
        assertEq(token.balanceOf(USER) - beforeBalance, AMOUNT + _principalDelayReward());
    }

    function test_ThirdPartyCanStartAndClaimBothDelaysForStaker() public {
        uint32 id = _stake();
        address thirdParty = address(0xBAD);
        skip(STAKE_DAYS * 1 days);
        vm.prank(thirdParty);
        stakeContract.unstakeAndWithdraw(id);

        (uint256 principalStart,,,,) = stakeContract.principalDelays(id);
        (uint256 rewardStart,,,,) = stakeContract.rewardDelays(id);
        assertEq(principalStart, block.timestamp);
        assertEq(rewardStart, block.timestamp);
        assertEq(token.balanceOf(USER), 900e18);
        assertEq(token.balanceOf(thirdParty), 0);

        skip(DELAY_DAYS * 1 days);
        vm.prank(thirdParty);
        stakeContract.unstakeAndWithdraw(id);
        assertEq(token.balanceOf(USER), 1000e18 + _reward(OLD_APR) + _principalDelayReward() + _rewardDelayReward());
        assertEq(token.balanceOf(thirdParty), 0);
    }

    function test_NewDelayConfigAppliesOnlyToLaterRequests() public {
        uint32 firstId = _stake();
        uint32 secondId = _stake();
        skip(STAKE_DAYS * 1 days);
        vm.prank(USER);
        stakeContract.unstake(firstId);

        vm.startPrank(ADMIN);
        stakeContract.updateDelayDays(30);
        stakeContract.updateDelayApr(100_000);
        vm.stopPrank();
        vm.prank(USER);
        stakeContract.unstake(secondId);

        (uint256 firstStart, uint256 firstEnd, uint256 firstDelayReward,,) = stakeContract.principalDelays(firstId);
        (uint256 secondStart, uint256 secondEnd, uint256 secondDelayReward,,) = stakeContract.principalDelays(secondId);
        assertEq(firstEnd - firstStart, DELAY_DAYS * 1 days);
        assertEq(firstDelayReward, _principalDelayReward());
        assertEq(secondEnd - secondStart, 30 days);
        assertEq(secondDelayReward, (AMOUNT * 100_000 * 30) / 365 / 1e6);
    }

    function test_InsufficientRewardsCanBeFundedAndRetried() public {
        uint32 id = _stake();
        skip(STAKE_DAYS * 1 days);
        vm.prank(USER);
        stakeContract.withdraw(id);
        skip(DELAY_DAYS * 1 days);

        vm.prank(REWARDS);
        token.transfer(address(0xDEAD), 1000e18);
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(StakeCommon.InsufficientRewardsAmount.selector, id));
        stakeContract.withdraw(id);
        (,,,,,,,,, uint256 paidBefore) = stakeContract.stakes(id);
        assertEq(paidBefore, 0);

        token.mint(REWARDS, _reward(OLD_APR) + _rewardDelayReward());
        vm.prank(USER);
        stakeContract.withdraw(id);
        (,,,,,,,,, uint256 paidAfter) = stakeContract.stakes(id);
        assertEq(paidAfter, _reward(OLD_APR));
    }

    function test_PrincipalDelayRewardFundingIsAtomic() public {
        uint32 id = _stake();
        skip(STAKE_DAYS * 1 days);
        vm.prank(USER);
        stakeContract.unstake(id);
        skip(DELAY_DAYS * 1 days);

        vm.prank(REWARDS);
        token.transfer(address(0xDEAD), 1000e18);
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(StakeCommon.InsufficientRewardsAmount.selector, id));
        stakeContract.unstake(id);
        (,,,, uint32 unstakeTimestamp,,,,,) = stakeContract.stakes(id);
        assertEq(unstakeTimestamp, 0);
        assertEq(stakeContract.totalStakeAmount(), AMOUNT);
        assertEq(token.balanceOf(USER), 900e18);

        token.mint(REWARDS, _principalDelayReward());
        vm.prank(USER);
        stakeContract.unstake(id);
        assertEq(token.balanceOf(USER), 1000e18 + _principalDelayReward());
    }
}
