// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AXNVStaking is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    uint256 public constant APR = 8; // 8%
    uint256 public constant YEAR = 365 days;

    uint256 public minStake = 15000 * 1e18;

    uint256 public totalStaked;
    uint256 public totalRewardsReserved;
    uint256 public totalPenaltiesCollected;

    bool public paused;

    uint256 public emergencyPenalty = 10; // 10%

    // This is an owner action cooldown, not a true queued timelock.
    uint256 public constant OWNER_ACTION_COOLDOWN = 1 days;
    uint256 public lastOwnerActionTime;

    struct Stake {
        address user;
        uint256 amount;
        uint256 reward;
        uint256 startTime;
        uint256 endTime;
        bool claimed;
    }

    Stake[] public stakes;
    mapping(address => uint256[]) public userStakeIds;

    uint256[] public durations = [
        30 days,
        90 days,
        180 days,
        365 days
    ];

    event Staked(address indexed user, uint256 indexed id, uint256 amount, uint256 duration);
    event Unstaked(address indexed user, uint256 indexed id, uint256 amount, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 indexed id, uint256 refund, uint256 penalty);
    event Paused(bool status);
    event RewardsFunded(address indexed funder, uint256 amount);
    event MinStakeUpdated(uint256 oldMinStake, uint256 newMinStake);
    event PenaltyUpdated(uint256 oldPenalty, uint256 newPenalty);
    event AXNVRecovered(address indexed to, uint256 amount);
    event ERC20Recovered(address indexed token, address indexed to, uint256 amount);

    modifier notPaused() {
        require(!paused, "Paused");
        _;
    }

    modifier ownerCooldown() {
        require(
            block.timestamp >= lastOwnerActionTime + OWNER_ACTION_COOLDOWN,
            "Owner action cooldown"
        );
        _;
        lastOwnerActionTime = block.timestamp;
    }

    constructor(address _token) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token");

        token = IERC20(_token);
        lastOwnerActionTime = block.timestamp;
    }

    // ================= STAKE =================

    function stake(uint256 amount, uint8 durationId) external nonReentrant notPaused {
        require(amount >= minStake, "Below min");
        require(durationId < durations.length, "Invalid duration");

        uint256 duration = durations[durationId];
        uint256 reward = (amount * APR * duration) / (YEAR * 100);

        require(availableRewardPool() >= reward, "Insufficient rewards");

        token.safeTransferFrom(msg.sender, address(this), amount);

        totalStaked += amount;
        totalRewardsReserved += reward;

        stakes.push(
            Stake({
                user: msg.sender,
                amount: amount,
                reward: reward,
                startTime: block.timestamp,
                endTime: block.timestamp + duration,
                claimed: false
            })
        );

        uint256 id = stakes.length - 1;
        userStakeIds[msg.sender].push(id);

        emit Staked(msg.sender, id, amount, duration);
    }

    // ================= UNSTAKE =================

    function unstake(uint256 id) external nonReentrant {
        require(id < stakes.length, "Invalid stake ID");

        Stake storage s = stakes[id];

        require(s.user == msg.sender, "Not owner");
        require(!s.claimed, "Already claimed");
        require(block.timestamp >= s.endTime, "Still locked");

        s.claimed = true;

        totalStaked -= s.amount;
        totalRewardsReserved -= s.reward;

        token.safeTransfer(msg.sender, s.amount + s.reward);

        emit Unstaked(msg.sender, id, s.amount, s.reward);
    }

    // ================= EARLY EXIT =================

    function emergencyWithdraw(uint256 id) external nonReentrant {
        require(id < stakes.length, "Invalid stake ID");

        Stake storage s = stakes[id];

        require(s.user == msg.sender, "Not owner");
        require(!s.claimed, "Already claimed");
        require(block.timestamp < s.endTime, "Use normal unstake");

        s.claimed = true;

        totalStaked -= s.amount;
        totalRewardsReserved -= s.reward;

        uint256 penalty = (s.amount * emergencyPenalty) / 100;
        uint256 refund = s.amount - penalty;

        totalPenaltiesCollected += penalty;

        token.safeTransfer(msg.sender, refund);

        emit EmergencyWithdraw(msg.sender, id, refund, penalty);
    }

    // ================= FUND REWARDS =================

    function fundRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Zero amount");

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit RewardsFunded(msg.sender, amount);
    }

    // ================= ADMIN =================

    function setPaused(bool _status) external onlyOwner ownerCooldown {
        paused = _status;

        emit Paused(_status);
    }

    function setPenalty(uint256 _penalty) external onlyOwner ownerCooldown {
        require(_penalty <= 20, "Too high");

        uint256 oldPenalty = emergencyPenalty;
        emergencyPenalty = _penalty;

        emit PenaltyUpdated(oldPenalty, _penalty);
    }

    function setMinStake(uint256 _minStake) external onlyOwner ownerCooldown {
        require(_minStake > 0, "Zero min");

        uint256 oldMinStake = minStake;
        minStake = _minStake;

        emit MinStakeUpdated(oldMinStake, _minStake);
    }

    // ================= SAFE AXNV RECOVERY =================

    /*
        This function prevents AXNV from getting stuck.

        It only allows the owner to recover AXNV that is NOT needed for:
        1. user principal/staked tokens
        2. reserved staking rewards

        Available AXNV = contract AXNV balance - totalStaked - totalRewardsReserved

        This means users' staked AXNV and promised rewards remain protected.
    */
    function recoverAvailableAXNV(uint256 amount, address to) external onlyOwner ownerCooldown {
        require(paused, "Pause first");
        require(to != address(0), "Invalid recipient");

        uint256 available = availableRewardPool();
        require(amount <= available, "Exceeds available AXNV");

        token.safeTransfer(to, amount);

        emit AXNVRecovered(to, amount);
    }

    /*
        Rescue any non-AXNV ERC20 token accidentally sent to this contract.
        AXNV recovery must use recoverAvailableAXNV().
    */
    function rescueERC20(address _token, uint256 amount, address to) external onlyOwner ownerCooldown {
        require(paused, "Pause first");
        require(_token != address(token), "Use recoverAvailableAXNV");
        require(to != address(0), "Invalid recipient");

        IERC20(_token).safeTransfer(to, amount);

        emit ERC20Recovered(_token, to, amount);
    }

    // ================= VIEW =================

    function availableRewardPool() public view returns (uint256) {
        uint256 bal = token.balanceOf(address(this));
        uint256 required = totalStaked + totalRewardsReserved;

        if (bal <= required) {
            return 0;
        }

        return bal - required;
    }

    function requiredAXNVBalance() external view returns (uint256) {
        return totalStaked + totalRewardsReserved;
    }

    function contractAXNVBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getUserStakes(address user) external view returns (uint256[] memory) {
        return userStakeIds[user];
    }

    function getDurations() external view returns (uint256[] memory) {
        return durations;
    }

    function stakesCount() external view returns (uint256) {
        return stakes.length;
    }
}
