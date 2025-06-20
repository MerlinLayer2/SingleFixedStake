// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StakeCommon } from "./StakeCommon.sol";

contract SimpleStake is StakeCommon {
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
     * - `_endTimestamp`: stake end timestamp.
     * - `_stakeCap`: stake cap.
     */
    function initialize(
        address _initialOwner,
        address _stakeToken,
        uint32 _endTimestamp,
        uint256 _stakeCap
    )
        public
        override
        initializer
    {
        super.initialize(_initialOwner, _stakeToken, _endTimestamp, _stakeCap);
    }

    function stake(uint256 _amount) external whenNotPaused nonReentrant payable {
        if (_amount < MIN_AMOUNT) revert TooSmallStakeAmount();
        if (totalStakeAmount + _amount > stakeCap) revert OverStakeCap();

        address staker = msg.sender;
        if (stakeToken == address(0)) {
            if (msg.value != _amount) revert InvalidStakeAmount();
        } else {
            IERC20(stakeToken).transferFrom(staker, address(this), _amount);
        }
        totalStakeAmount += _amount;

        UserStake storage userStake = stakes[staker];
        if (userStake.startTimestamp == 0) {
            stakes[staker] = UserStake(
                staker, //account
                uint32(block.timestamp), //startTimestamp
                endTimestamp, //endTimestamp
                0, //unstakeTimestamp
                uint32(block.timestamp), //updateTimestamp
                _amount //amount
            );
        } else {
            userStake.amount += _amount;
            userStake.updateTimestamp = uint32(block.timestamp);
        }

        emit Stake(staker, userStake, _amount, block.timestamp);
    }

    function unstake() external whenNotPaused nonReentrant {
        address staker = msg.sender;
        UserStake storage userStake = stakes[staker];

        if (userStake.startTimestamp == 0) revert NotFoundStaking(staker);
        if (userStake.endTimestamp > block.timestamp) revert NotDueYet(staker);
        if (userStake.unstakeTimestamp > 0) revert AlreadyUnstaked(staker);

        totalStakeAmount -= userStake.amount;
        userStake.unstakeTimestamp = uint32(block.timestamp);

        if (stakeToken == address(0)) {
            (bool success,) = staker.call{value: userStake.amount}(new bytes(0));
            if (!success) revert UnstakeFailed(staker);
        } else {
            IERC20(stakeToken).transfer(staker, userStake.amount);
        }
        emit Unstake(staker, userStake, block.timestamp);
    }
}
