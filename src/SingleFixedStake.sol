// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StakeCommon } from "./StakeCommon.sol";

contract SingleFixedStake is StakeCommon {
    using SafeERC20 for IERC20;

    string public constant VERSION = "2.0.0";

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialization function
     *
     * - `_initialOwner`：the initial owner is set to the address provided by the deployer. This can
     *      later be changed with {transferOwnership}.
     * - `_stakeToken`: stake token to get rewards.
     * - `_rewardsSourceAddress`:the rewards contract address.
     * - `_ndays`: stake number days.
     * - `_apr`: stake apr.
     * - `_stakeCap`: stake cap.
     */
    function initialize(
        address _initialOwner,
        address _stakeToken,
        address _rewardsSourceAddress,
        uint256 _ndays,
        uint256 _apr,
        uint256 _stakeCap
    )
        public
        override
        initializer
    {
        super.initialize(_initialOwner, _stakeToken, _rewardsSourceAddress, _ndays, _apr, _stakeCap);
    }

    function stake(uint256 _amount) external whenNotPaused nonReentrant {
        if (_amount < MIN_AMOUNT) revert TooSmallStakeAmount();
        if (totalStakeAmount + _amount > stakeCap) revert OverStakeCap();

        address staker = msg.sender;
        IERC20(stakeToken).safeTransferFrom(staker, address(this), _amount);
        totalStakeAmount += _amount;

        uint32 id = nextStakeId;
        nextStakeId += 1;
        uint32 endTimestamp = uint32(block.timestamp + ndays * SECONDS_PER_DAY);
        uint256 totalRewards = _calTotalRewards(_amount);

        StakeItem memory stakeItem = StakeItem(
            staker, //account
            id, //id
            uint32(block.timestamp), //startTimestamp
            endTimestamp, //endTimestamp
            0, //unstakeTimestamp
            0, //withdrawTimestamp
            uint32(block.timestamp), //updateTimestamp
            _amount, //amount
            totalRewards, //totalRewards
            0 //withdrawRewards
        );
        stakes[id] = stakeItem;
        userStakeIds[staker].push(id);
        userStakeAmount[staker] += _amount;

        emit Stake(staker, stakeItem, block.timestamp);
    }

    function unstake(uint32 _id) external whenNotPaused nonReentrant {
        if (stakes[_id].unstakeTimestamp > 0) revert AlreadyUnstaked(_id);
        bool ready = _checkDelay(_id, principalDelays[_id], stakes[_id].amount, DelayKind.Principal);
        if (!ready) return;
        _unstake(_id);
    }

    function _unstake(uint32 _id) internal {
        StakeItem storage stakeItem = stakes[_id];
        address staker = stakeItem.account;
        DelayItem storage delayItem = principalDelays[_id];
        if (stakeItem.startTimestamp == 0) revert NotFoundStaking(_id);
        if (stakeItem.endTimestamp > block.timestamp) revert NotDueYet(_id);
        if (delayItem.endTimestamp == 0 || block.timestamp < delayItem.endTimestamp) {
            revert DelayNotDueYet(_id);
        }
        if (stakeItem.unstakeTimestamp > 0) revert AlreadyUnstaked(_id);
        uint256 delayReward = delayItem.delayRewardWithdrawn ? 0 : delayItem.delayReward;
        if (IERC20(stakeToken).balanceOf(rewardsSourceAddress) < delayReward) revert InsufficientRewardsAmount(_id);

        totalStakeAmount -= stakeItem.amount;
        stakeItem.unstakeTimestamp = uint32(block.timestamp);
        userStakeAmount[staker] -= stakeItem.amount;

        delayItem.delayRewardWithdrawn = true;
        delayItem.updateTimestamp = block.timestamp;
        IERC20(stakeToken).safeTransfer(staker, stakeItem.amount);
        if (delayReward > 0) IERC20(stakeToken).safeTransferFrom(rewardsSourceAddress, staker, delayReward);
        emit Unstake(staker, stakeItem, block.timestamp);
        if (delayReward > 0) emit DelayRewardWithdrawn(_id, staker, DelayKind.Principal, delayReward);
    }

    function withdraw(uint32 _id) external whenNotPaused nonReentrant {
        uint256 remainingRewards = stakes[_id].totalRewards - stakes[_id].withdrawnRewards;
        bool ready = _checkDelay(_id, rewardDelays[_id], remainingRewards, DelayKind.Rewards);
        if (!ready) return;
        _withdraw(_id);
    }

    function _withdraw(uint32 _id) internal {
        StakeItem storage stakeItem = stakes[_id];
        address staker = stakeItem.account;
        DelayItem storage delayItem = rewardDelays[_id];
        if (stakeItem.startTimestamp == 0) revert NotFoundStaking(_id);
        if (stakeItem.endTimestamp > block.timestamp) revert NotDueYet(_id);
        if (delayItem.endTimestamp == 0 || block.timestamp < delayItem.endTimestamp) revert DelayNotDueYet(_id);
        uint256 remainingRewards = stakeItem.totalRewards - stakeItem.withdrawnRewards;
        uint256 delayReward = delayItem.delayRewardWithdrawn ? 0 : delayItem.delayReward;
        uint256 payout = remainingRewards + delayReward;
        if (payout == 0) revert AlreadyWithdrawn(_id);
        if (IERC20(stakeToken).balanceOf(rewardsSourceAddress) < payout) revert InsufficientRewardsAmount(_id);

        stakeItem.withdrawnRewards = stakeItem.totalRewards;
        stakeItem.withdrawTimestamp = uint32(block.timestamp);
        stakeItem.updateTimestamp = uint32(block.timestamp);
        delayItem.delayRewardWithdrawn = true;
        delayItem.updateTimestamp = block.timestamp;
        IERC20(stakeToken).safeTransferFrom(rewardsSourceAddress, staker, payout);

        if (remainingRewards > 0) emit Withdraw(staker, stakeItem, remainingRewards, block.timestamp);
        if (delayReward > 0) emit DelayRewardWithdrawn(_id, staker, DelayKind.Rewards, delayReward);
    }

    function unstakeAndWithdraw(uint32 _id) external whenNotPaused nonReentrant {
        StakeItem storage stakeItem = stakes[_id];
        if (stakeItem.startTimestamp == 0) revert NotFoundStaking(_id);
        bool hasPrincipal = stakeItem.unstakeTimestamp == 0;
        bool hasRewards = stakeItem.withdrawnRewards < stakeItem.totalRewards;
        if (!hasPrincipal && !hasRewards) revert NothingToClaim(_id);
        bool principalReady;
        bool rewardsReady;
        if (hasPrincipal) {
            principalReady = _checkDelay(_id, principalDelays[_id], stakeItem.amount, DelayKind.Principal);
        }
        if (hasRewards) {
            rewardsReady = _checkDelay(
                _id, rewardDelays[_id], stakeItem.totalRewards - stakeItem.withdrawnRewards, DelayKind.Rewards
            );
        }
        if (principalReady) _unstake(_id);
        if (rewardsReady) _withdraw(_id);
    }

    function _checkDelay(
        uint32 _id,
        DelayItem storage delayItem,
        uint256 rewardBase,
        DelayKind kind
    )
        internal
        returns (bool ready)
    {
        StakeItem storage stakeItem = stakes[_id];
        if (stakeItem.startTimestamp == 0) revert NotFoundStaking(_id);
        if (msg.sender != stakeItem.account) revert NotStakeOwner(_id);
        if (stakeItem.endTimestamp > block.timestamp) revert NotDueYet(_id);

        if (delayItem.endTimestamp == 0) {
            if (delayDays == 0) revert DelayNotConfigured();
            if (rewardBase == 0) revert AlreadyWithdrawn(_id);

            uint256 endTimestamp = block.timestamp + delayDays * SECONDS_PER_DAY;
            uint256 delayReward = Math.mulDiv(rewardBase, delayApr * delayDays, 365 * APR_SCALE_FACTOR);
            delayItem.startTimestamp = block.timestamp;
            delayItem.endTimestamp = endTimestamp;
            delayItem.delayReward = delayReward;
            delayItem.updateTimestamp = block.timestamp;
            emit DelayStarted(_id, stakeItem.account, kind, block.timestamp, endTimestamp, delayReward);
            return false;
        }
        return block.timestamp >= delayItem.endTimestamp;
    }

    function calTotalRewards(uint32 _id) external view returns (uint256) {
        StakeItem storage stakeItem = stakes[_id];
        if (stakeItem.startTimestamp == 0) revert NotFoundStaking(_id);
        return stakeItem.totalRewards;
    }

    function calCurrentRewards(uint32 _id) external view returns (uint256) {
        StakeItem storage stakeItem = stakes[_id];
        if (stakeItem.startTimestamp == 0) revert NotFoundStaking(_id);
        return _calCurrentRewards(stakeItem.totalRewards, stakeItem.startTimestamp, stakeItem.endTimestamp);
    }

    function getUserTotalStakeAmountExt(address _user) external view returns (uint256) {
        return userStakeAmount[_user];
    }

    function getUserTotalStakeAmount(address _user) external view returns (uint256) {
        uint256[] memory stakeIds = _getUserStakeIds(_user);
        uint256 totalStakeAmount = 0;
        for (uint32 i = 0; i < stakeIds.length; i++) {
            StakeItem storage stakeItem = stakes[stakeIds[i]];
            if (stakeItem.unstakeTimestamp == 0) {
                totalStakeAmount += stakeItem.amount;
            }
        }
        return totalStakeAmount;
    }
}
