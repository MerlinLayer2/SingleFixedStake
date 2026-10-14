// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract StakeCommon is OwnableUpgradeable, UUPSUpgradeable {
    uint256 public constant MIN_AMOUNT = 1e18;
    uint256 public constant SECONDS_PER_DAY = 86_400;
    uint256 public constant APR_SCALE_FACTOR = 1e6;
    uint256 private _nonReentrantStatus;
    address public pauseAdmin;
    bool public paused;

    address public stakeToken;
    address public rewardsSourceAddress;
    uint256 public ndays = 180;
    uint256 public apr = 450_000;
    uint256 public stakeCap = 2.1e27;

    struct StakeItem {
        address account;
        uint32 id;
        uint32 startTimestamp;
        uint32 endTimestamp;
        uint32 unstakeTimestamp;
        uint32 withdrawTimestamp;
        uint32 updateTimestamp;
        uint256 amount;
        uint256 totalRewards;
        uint256 withdrawnRewards;
    }

    mapping(uint256 => StakeItem) public stakes;
    mapping(address => uint256[]) public userStakeIds;
    uint32 public nextStakeId;
    uint256 public totalStakeAmount;
    mapping(address => uint256) public userStakeAmount;

    // V2 storage is appended so existing proxy storage and stake records keep their layout.
    uint256 public delayDays;
    uint256 public delayApr;

    struct DelayItem {
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 delayReward;
        uint256 updateTimestamp;
        bool delayRewardWithdrawn;
    }

    mapping(uint256 => DelayItem) public principalDelays;
    mapping(uint256 => DelayItem) public rewardDelays;

    enum DelayKind {
        Principal,
        Rewards
    }

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

    function initialize(
        address _initialOwner,
        address _stakeToken,
        address _rewardsSourceAddress,
        uint256 _ndays,
        uint256 _apr,
        uint256 _stakeCap
    )
        public
        virtual
    {
        if (_initialOwner == address(0)) revert ZeroAddress("init owner");
        if (_stakeToken == address(0)) revert ZeroAddress("init stakeToken");
        if (_rewardsSourceAddress == address(0)) revert ZeroAddress("init rewardsSourceAddress");
        if (_ndays == 0) revert ZeroValue("init ndays");
        if (_apr == 0) revert ZeroValue("init apr");
        if (_stakeCap == 0) revert ZeroValue("init stakeCap");

        stakeToken = _stakeToken;
        rewardsSourceAddress = _rewardsSourceAddress;
        ndays = _ndays;
        apr = _apr;
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
        uint256 oldStakeCap = stakeCap;
        stakeCap = _stakeCap;
        emit UpdateStakeCap(msg.sender, oldStakeCap, stakeCap);
    }

    function initializeV2(uint256 _delayDays, uint256 _delayApr) external onlyOwner reinitializer(2) {
        if (_delayDays == 0) revert ZeroValue("init delayDays");
        delayDays = _delayDays;
        delayApr = _delayApr;
        emit DelayDaysUpdated(0, _delayDays);
        emit DelayAprUpdated(0, _delayApr);
    }

    function updateApr(uint256 _apr) external onlyOwner {
        if (_apr == 0) revert ZeroValue("update apr");
        uint256 oldApr = apr;
        apr = _apr;
        emit AprUpdated(oldApr, _apr);
    }

    function updateDelayDays(uint256 _delayDays) external onlyOwner {
        if (_delayDays == 0) revert ZeroValue("update delayDays");
        uint256 oldDelayDays = delayDays;
        delayDays = _delayDays;
        emit DelayDaysUpdated(oldDelayDays, _delayDays);
    }

    function updateDelayApr(uint256 _delayApr) external onlyOwner {
        uint256 oldDelayApr = delayApr;
        delayApr = _delayApr;
        emit DelayAprUpdated(oldDelayApr, _delayApr);
    }

    function _calTotalRewards(uint256 amount) internal view returns (uint256) {
        return (amount * apr * ndays) / 365 / APR_SCALE_FACTOR;
    }

    function _calCurrentRewards(
        uint256 totalRewards,
        uint32 startTimestamp,
        uint32 endTimestamp
    )
        internal
        view
        returns (uint256)
    {
        uint256 totalSeconds = endTimestamp - startTimestamp;
        uint256 elapsed = block.timestamp - startTimestamp;
        if (elapsed > totalSeconds) elapsed = totalSeconds;
        return Math.mulDiv(totalRewards, elapsed, totalSeconds);
    }

    function _getUserStakeIds(address _user) internal view returns (uint256[] memory) {
        uint256 userStakeCount = userStakeIds[_user].length;
        uint256[] memory stakeIds = new uint256[](userStakeCount);
        for (uint32 i = 0; i < userStakeCount; i++) {
            stakeIds[i] = userStakeIds[_user][i];
        }
        return stakeIds;
    }

    // Error definitions
    error ZeroAddress(string msg);
    error ZeroValue(string msg);
    error OverStakeCap();
    error TooSmallStakeAmount();
    error NotFoundStaking(uint32 id);
    error NotDueYet(uint32 id);
    error AlreadyUnstaked(uint32 id);
    error AlreadyWithdrawn(uint32 id);
    error InvalidWithdrawDiff(uint32 id);
    error InsufficientRewardsAmount(uint32 id);
    error IllegalPausePermissions(address sender);
    error AlreadyPaused();
    error ReentrancyGuardStatus();
    error NotStakeOwner(uint32 id);
    error DelayNotConfigured();
    error DelayNotDueYet(uint32 id);
    error NothingToClaim(uint32 id);

    // Event definitions
    event UpdateStakeCap(address adminSetter, uint256 oldStakeCap, uint256 stakeCap);
    event PauseAdminChanged(address adminSetter, address oldAddress, address newAddress);
    event PauseEvent(address adminSetter, bool paused);
    event Stake(address msgSender, StakeItem stakeItem, uint256 stakeTimestamp);
    event Unstake(address msgSender, StakeItem stakeItem, uint256 unstakeTimestamp);
    event Withdraw(address msgSender, StakeItem stakeItem, uint256 withdrawRewards, uint256 withdrawTimestamp);
    event AprUpdated(uint256 oldApr, uint256 newApr);
    event DelayDaysUpdated(uint256 oldDelayDays, uint256 newDelayDays);
    event DelayAprUpdated(uint256 oldDelayApr, uint256 newDelayApr);
    event DelayStarted(
        uint32 indexed id,
        address indexed account,
        DelayKind indexed kind,
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256 delayReward
    );
    event DelayRewardWithdrawn(uint32 indexed id, address indexed account, DelayKind indexed kind, uint256 delayReward);
}
