// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { StakeCommon } from "./StakeCommon.sol";

contract BtcStake is StakeCommon {
    using SafeERC20 for IERC20;

    string public constant VERSION = "1.0.0";

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialization function
     *
     * - `_initialOwner`：the initial owner is set to the address provided by the deployer. This can
     *      later be changed with {transferOwnership}.
     * - `_endTimestamp`: stake end timestamp.
     * - `_stakeCap`: stake cap.
     */
    function initialize(address _initialOwner, uint32 _endTimestamp, uint256 _stakeCap) public override initializer {
        super.initialize(_initialOwner, _endTimestamp, _stakeCap);
    }

    function stake(uint256 _amount) external payable whenNotPaused nonReentrant {
        if (stakePaused) revert StakePaused();
        if (block.timestamp > endTimestamp) revert AlreadyExpired();
        if (_amount < MIN_AMOUNT) revert TooSmallStakeAmount();
        if (msg.value != _amount) revert InvalidStakeAmount();
        if (totalStakeAmount + _amount > stakeCap) revert OverStakeCap();

        address staker = msg.sender;
        UserStake storage userStake = stakes[staker];
        if (userStake.amount == 0) {
            stakes[staker] = UserStake(
                staker, //account
                0, //unstakeTimestamp
                _amount //amount
            );
        } else {
            userStake.amount += _amount;
        }

        totalStakeAmount += _amount;
        emit Stake(staker, _amount, block.timestamp);
    }

    function unstake() external whenNotPaused nonReentrant {
        address staker = msg.sender;
        UserStake storage userStake = stakes[staker];
        if (userStake.amount == 0) revert NotFoundStaking(staker);
        if (endTimestamp > block.timestamp) revert NotDueYet(staker);
        if (userStake.unstakeTimestamp > 0) revert AlreadyUnstaked(staker);

        totalStakeAmount -= userStake.amount;
        userStake.unstakeTimestamp = uint32(block.timestamp);

        (bool success,) = staker.call{ value: userStake.amount }(new bytes(0));
        if (!success) revert UnstakeFailed(staker);
        emit Unstake(staker, userStake.amount, block.timestamp);
    }
}
