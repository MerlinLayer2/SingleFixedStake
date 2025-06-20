// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract StakeCommon is OwnableUpgradeable, UUPSUpgradeable {
    uint256 public constant MIN_AMOUNT = 1e15;
    uint256 private _nonReentrantStatus;
    address public pauseAdmin;
    bool public paused;

    address public stakeToken;
    uint32 public endTimestamp;
    uint256 public stakeCap = 50e18;
    bool public stakePaused = false;

    struct UserStake {
        address account;
        uint32 startTimestamp;
        uint32 unstakeTimestamp;
        uint32 updateTimestamp;
        uint256 amount;
    }

    mapping(address => UserStake) public stakes;
    uint256 public totalStakeAmount;

    modifier nonReentrant() {
        if (_nonReentrantStatus != 0) revert ReentrancyGuardStatus();
        _nonReentrantStatus = 1;
        _;
        _nonReentrantStatus = 0;
    }

    /**
     * @dev Authorizes the upgrade of the contract. Only the default admin can upgrade.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        // Only admin can upgrade the contract
    }

    function initialize(address _initialOwner, uint32 _endTimestamp, uint256 _stakeCap) public virtual {
        if (_initialOwner == address(0)) revert ZeroAddress("init owner");
        if (_endTimestamp == 0 || _endTimestamp <= block.timestamp) revert ZeroValue("init endTimestamp");
        if (_stakeCap == 0) revert ZeroValue("init stakeCap");

        endTimestamp = _endTimestamp;
        stakeCap = _stakeCap;

        __UUPSUpgradeable_init();
        __Ownable_init_unchained(_initialOwner);
    }

    //Pause ...
    function setPauseAdmin(address _account) public onlyOwner {
        if (_account == address(0)) revert ZeroAddress("set pauseAdmin");
        address oldPauseAdmin = pauseAdmin;
        pauseAdmin = _account;
        emit PauseAdminChanged(msg.sender, oldPauseAdmin, pauseAdmin);
    }

    modifier whenNotPaused() {
        if (paused) revert AlreadyPaused();
        _;
    }

    /**
     * @dev Pause the activity, only by pauseAdmin.
     */
    function pause() public whenNotPaused {
        if (msg.sender != pauseAdmin) revert IllegalPausePermissions(msg.sender);
        paused = true;
        emit PauseEvent(msg.sender, paused);
    }

    /**
     * @dev Unpause the activity, only by owner.
     */
    function unpause() public onlyOwner {
        paused = false;
        emit PauseEvent(msg.sender, paused);
    }

    function updateStakeCap(uint256 _stakeCap) external onlyOwner {
        if (_stakeCap == 0) revert ZeroValue("update stakeCap");
        emit UpdateStakeCap(msg.sender, stakeCap, _stakeCap);
        stakeCap = _stakeCap;
    }

    function updateEndTimestamp(uint32 _endTimestamp) external onlyOwner {
        if (_endTimestamp <= 0) revert ZeroValue("update endTimestamp");
        emit UpdateEndTimestamp(msg.sender, endTimestamp, _endTimestamp);
        endTimestamp = _endTimestamp;
    }

    function updateStakePaused(bool _stakePaused) external onlyOwner {
        stakePaused = _stakePaused;
        emit UpdateStakePaused(msg.sender, _stakePaused);
    }

    // Error definitions
    error ZeroAddress(string msg);
    error ZeroValue(string msg);
    error OverStakeCap();
    error InvalidStakeAmount();
    error StakePaused();
    error TooSmallStakeAmount();
    error NotFoundStaking(address staker);
    error NotDueYet(address staker);
    error AlreadyUnstaked(address staker);
    error UnstakeFailed(address staker);
    error IllegalPausePermissions(address sender);
    error AlreadyPaused();
    error ReentrancyGuardStatus();

    // Event definitions
    event UpdateStakeCap(address adminSetter, uint256 oldStakeCap, uint256 stakeCap);
    event UpdateEndTimestamp(address adminSetter, uint256 oldEndTimestamp, uint256 endTimestamp);
    event UpdateStakePaused(address adminSetter, bool stakePaused);
    event PauseAdminChanged(address adminSetter, address oldAddress, address newAddress);
    event PauseEvent(address adminSetter, bool paused);
    event Stake(address msgSender, UserStake userStake, uint256 amount, uint256 stakeTimestamp);
    event Unstake(address msgSender, UserStake userStake, uint256 unstakeTimestamp);
}
