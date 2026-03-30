// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AXNVStaking is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    uint256 public constant APR = 8; // 8%
    uint256 public constant YEAR = 365 days;

    uint256 public minStake = 15000 * 1e18;

    uint256 public totalStaked;
    uint256 public totalRewardsReserved;

    bool public paused;

    uint256 public emergencyPenalty = 10; // 10%

    // Timelock
    uint256 public constant TIMELOCK = 1 days;
    uint256 public lastActionTime;

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

    // EVENTS
    event Staked(address indexed user, uint256 indexed id, uint256 amount, uint256 duration);
    event Unstaked(address indexed user, uint256 indexed id, uint256 amount, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 indexed id, uint256 refund);
    event Paused(bool status);
    event Rescue(address token, uint256 amount);

    modifier notPaused() {
        require(!paused, "Paused");
        _;
    }

    modifier timelocked() {
        require(block.timestamp >= lastActionTime + TIMELOCK, "Timelocked");
        _;
        lastActionTime = block.timestamp;
    }

	constructor(address _token) {
		require(_token != address(0), "Invalid token");

		token = IERC20(_token);
		lastActionTime = block.timestamp;

		_transferOwnership(msg.sender);
	}

    // ================= STAKE =================

    function stake(uint256 amount, uint8 durationId) external nonReentrant notPaused {
        require(amount >= minStake, "Below min");
        require(durationId < durations.length, "Invalid duration");

        uint256 duration = durations[durationId];

        uint256 reward = (amount * APR * duration) / (YEAR * 100);

        require(_availableRewardPool() >= reward, "Insufficient rewards");

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
        Stake storage s = stakes[id];

        require(s.user == msg.sender, "Not owner");
        require(!s.claimed, "Claimed");

        require(block.timestamp >= s.endTime, "Still locked");

        s.claimed = true;

        totalStaked -= s.amount;
        totalRewardsReserved -= s.reward;

        token.safeTransfer(msg.sender, s.amount + s.reward);

        emit Unstaked(msg.sender, id, s.amount, s.reward);
    }

    // ================= EARLY EXIT =================

    function emergencyWithdraw(uint256 id) external nonReentrant {
        Stake storage s = stakes[id];

        require(s.user == msg.sender, "Not owner");
        require(!s.claimed, "Claimed");

        s.claimed = true;

        totalStaked -= s.amount;
        totalRewardsReserved -= s.reward;

        uint256 penalty = (s.amount * emergencyPenalty) / 100;
        uint256 refund = s.amount - penalty;

        token.safeTransfer(msg.sender, refund);

        emit EmergencyWithdraw(msg.sender, id, refund);
    }

    // ================= ADMIN =================

    function setPaused(bool _status) external onlyOwner timelocked {
        paused = _status;
        emit Paused(_status);
    }

    function setPenalty(uint256 _penalty) external onlyOwner timelocked {
        require(_penalty <= 20, "Too high");
        emergencyPenalty = _penalty;
    }

    // ================= RESCUE =================

    function rescueERC20(address _token, uint256 amount) external onlyOwner timelocked {
        require(paused, "Pause first");

        if (_token == address(token)) {
            uint256 available = _availableRewardPool();
            require(amount <= available, "Exceeds available");
        }

        IERC20(_token).safeTransfer(msg.sender, amount);

        emit Rescue(_token, amount);
    }

    // ================= VIEW =================

    function _availableRewardPool() public view returns (uint256) {
        uint256 bal = token.balanceOf(address(this));
        return bal - totalStaked - totalRewardsReserved;
    }

    function getUserStakes(address user) external view returns (uint256[] memory) {
        return userStakeIds[user];
    }

    function getDurations() external view returns (uint256[] memory) {
        return durations;
    }
}