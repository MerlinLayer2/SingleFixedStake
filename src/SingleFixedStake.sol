// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StakeCommon } from "./StakeCommon.sol";

contract SingleFixedStake is StakeCommon {
    string public constant VERSION = "1.0.0";

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
        IERC20(stakeToken).transferFrom(staker, address(this), _amount);
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

        emit Stake(staker, stakeItem, block.timestamp);
    }

    function unstake(uint32 _id) external whenNotPaused nonReentrant {
        StakeItem storage stakeItem = stakes[_id];
        address staker = stakeItem.account;
        if (stakeItem.startTimestamp == 0) revert NotFoundStaking(_id);
        if (stakeItem.endTimestamp > block.timestamp) revert NotDueYet(_id);
        if (stakeItem.unstakeTimestamp > 0) revert AlreadyUnstaked(_id);

        totalStakeAmount -= stakeItem.amount;
        stakeItem.unstakeTimestamp = uint32(block.timestamp);

        IERC20(stakeToken).transfer(staker, stakeItem.amount); //withdraw stake token
        emit Unstake(staker, stakeItem, block.timestamp);
    }

    function withdrawRewards(uint32 _id) external whenNotPaused nonReentrant {
        StakeItem storage stakeItem = stakes[_id];
        address staker = stakeItem.account;
        if (stakeItem.startTimestamp == 0) revert NotFoundStaking(_id);
        if (stakeItem.withdrawRewards >= stakeItem.totalRewards) revert AlreadyWithdrawn(_id);
        uint256 diff = _calCurrentRewards(stakeItem.amount, stakeItem.startTimestamp, stakeItem.endTimestamp)
            - stakeItem.withdrawRewards;
        if (diff <= 0 || diff + stakeItem.withdrawRewards > stakeItem.totalRewards) revert InvalidWithdrawDiff(_id);
        if (IERC20(stakeToken).balanceOf(rewardsSourceAddress) < diff) revert InsufficientRewardsAmount(_id);

        stakeItem.withdrawRewards += diff;
        stakeItem.withdrawTimestamp = uint32(block.timestamp);
        stakeItem.updateTimestamp = uint32(block.timestamp);
        IERC20(stakeToken).transferFrom(rewardsSourceAddress, staker, diff); //withdraw diff rewards

        emit WithdrawRewards(staker, stakeItem, diff, block.timestamp);
    }

    function calTotalRewards(uint32 _id) external view returns (uint256) {
        StakeItem storage stakeItem = stakes[_id];
        if (stakeItem.startTimestamp == 0) revert NotFoundStaking(_id);
        return _calTotalRewards(stakeItem.amount);
    }

    function calCurrentRewards(uint32 _id) external view returns (uint256) {
        StakeItem storage stakeItem = stakes[_id];
        if (stakeItem.startTimestamp == 0) revert NotFoundStaking(_id);
        return _calCurrentRewards(stakeItem.amount, stakeItem.startTimestamp, stakeItem.endTimestamp);
    }
}
