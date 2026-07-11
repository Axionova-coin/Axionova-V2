// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AXNVStaking is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable axnv;

    uint256 public constant YEAR = 365 days;
    uint256 public constant ONE_MONTH = 30 days;
    uint256 public constant SIX_MONTHS = 180 days;

    uint256 public constant FIRST_PERIOD_APR = 5; // 5%
    uint256 public constant AFTER_SIX_MONTHS_APR = 8; // 8%

    uint256 public constant EARLY_PENALTY_BPS = 1_000; // 10%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    uint256 public constant STAKING_REWARD_CAP = 56_250_000 ether;

    uint256 public minStake = 10_000 ether;

    uint256 public totalStaked;
    uint256 public totalPenaltiesCollected;

    uint256 public totalRewardPoolFunded;
    uint256 public totalRewardsPaid;

    struct StakeInfo {
        address user;
        uint256 amount;
        uint256 startTime;
        uint256 rewardClaimed;
        bool withdrawn;
    }

    StakeInfo[] public stakes;

    mapping(address => uint256[]) private userStakeIds;

    event Staked(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        uint256 startTime
    );

    event RewardClaimed(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount
    );

    event Withdrawn(
        address indexed user,
        uint256 indexed stakeId,
        uint256 principalReturned,
        uint256 rewardPaid,
        uint256 penalty
    );

    event RewardsFunded(address indexed from, uint256 amount);
    event MinStakeUpdated(uint256 oldMinStake, uint256 newMinStake);
    event UnallocatedAXNVWithdrawn(address indexed to, uint256 amount);
    event ERC20Rescued(address indexed token, address indexed to, uint256 amount);

    constructor(address axnvToken, address initialOwner) Ownable(initialOwner) {
        require(axnvToken != address(0), "Invalid AXNV");
        require(initialOwner != address(0), "Invalid owner");

        axnv = IERC20(axnvToken);
    }

    // ------------------------------------------------------------
    // User Functions
    // ------------------------------------------------------------

    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount >= minStake, "Below minimum stake");

        axnv.safeTransferFrom(msg.sender, address(this), amount);

        uint256 stakeId = stakes.length;

        stakes.push(
            StakeInfo({
                user: msg.sender,
                amount: amount,
                startTime: block.timestamp,
                rewardClaimed: 0,
                withdrawn: false
            })
        );

        userStakeIds[msg.sender].push(stakeId);

        totalStaked += amount;

        emit Staked(msg.sender, stakeId, amount, block.timestamp);
    }

    function claimReward(uint256 stakeId) public nonReentrant whenNotPaused {
        require(stakeId < stakes.length, "Invalid stake");

        StakeInfo storage s = stakes[stakeId];

        require(s.user == msg.sender, "Not stake owner");
        require(!s.withdrawn, "Stake withdrawn");
        require(block.timestamp >= s.startTime + SIX_MONTHS, "Reward locked");

        uint256 reward = claimableReward(stakeId);

        require(reward > 0, "Nothing claimable");
        require(availableRewardPool() >= reward, "Insufficient reward pool");
        require(totalRewardsPaid + reward <= STAKING_REWARD_CAP, "Reward cap exceeded");

        s.rewardClaimed += reward;
        totalRewardsPaid += reward;

        axnv.safeTransfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, stakeId, reward);
    }

    function withdraw(uint256 stakeId) external nonReentrant whenNotPaused {
        require(stakeId < stakes.length, "Invalid stake");

        StakeInfo storage s = stakes[stakeId];

        require(s.user == msg.sender, "Not stake owner");
        require(!s.withdrawn, "Already withdrawn");

        uint256 elapsed = block.timestamp - s.startTime;

        uint256 principalReturned;
        uint256 rewardPaid;
        uint256 penalty;

        s.withdrawn = true;
        totalStaked -= s.amount;

        if (elapsed < ONE_MONTH) {
            penalty = (s.amount * EARLY_PENALTY_BPS) / BPS_DENOMINATOR;
            principalReturned = s.amount - penalty;

            totalPenaltiesCollected += penalty;

            axnv.safeTransfer(msg.sender, principalReturned);
        } else if (elapsed < SIX_MONTHS) {
            principalReturned = s.amount;

            axnv.safeTransfer(msg.sender, principalReturned);
        } else {
            principalReturned = s.amount;
            rewardPaid = claimableReward(stakeId);

            if (rewardPaid > 0) {
                require(availableRewardPool() >= rewardPaid, "Insufficient reward pool");
                require(
                    totalRewardsPaid + rewardPaid <= STAKING_REWARD_CAP,
                    "Reward cap exceeded"
                );

                s.rewardClaimed += rewardPaid;
                totalRewardsPaid += rewardPaid;
            }

            axnv.safeTransfer(msg.sender, principalReturned + rewardPaid);
        }

        emit Withdrawn(
            msg.sender,
            stakeId,
            principalReturned,
            rewardPaid,
            penalty
        );
    }

    // ------------------------------------------------------------
    // Reward Logic
    // ------------------------------------------------------------

    function accruedReward(uint256 stakeId) public view returns (uint256) {
        require(stakeId < stakes.length, "Invalid stake");

        StakeInfo memory s = stakes[stakeId];

        if (s.withdrawn) {
            return s.rewardClaimed;
        }

        uint256 elapsed = block.timestamp - s.startTime;

        if (elapsed < SIX_MONTHS) {
            return 0;
        }

        uint256 firstSixMonthReward =
            (s.amount * FIRST_PERIOD_APR * SIX_MONTHS) / (YEAR * 100);

        uint256 afterSixMonthsElapsed = elapsed - SIX_MONTHS;

        uint256 afterSixMonthsReward =
            (s.amount * AFTER_SIX_MONTHS_APR * afterSixMonthsElapsed) /
            (YEAR * 100);

        return firstSixMonthReward + afterSixMonthsReward;
    }

    function claimableReward(uint256 stakeId) public view returns (uint256) {
        require(stakeId < stakes.length, "Invalid stake");

        StakeInfo memory s = stakes[stakeId];

        if (s.withdrawn) {
            return 0;
        }

        uint256 accrued = accruedReward(stakeId);

        if (accrued <= s.rewardClaimed) {
            return 0;
        }

        return accrued - s.rewardClaimed;
    }

    // ------------------------------------------------------------
    // Owner Functions
    // ------------------------------------------------------------

    function fundRewards(uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(amount > 0, "Zero amount");
        require(
            totalRewardPoolFunded + amount <= STAKING_REWARD_CAP,
            "Reward cap exceeded"
        );

        totalRewardPoolFunded += amount;

        axnv.safeTransferFrom(msg.sender, address(this), amount);

        emit RewardsFunded(msg.sender, amount);
    }

    function setMinStake(uint256 newMinStake)
        external
        onlyOwner
    {
        require(newMinStake > 0, "Invalid min stake");

        uint256 oldMinStake = minStake;
        minStake = newMinStake;

        emit MinStakeUpdated(oldMinStake, newMinStake);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawUnallocatedAXNV(address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(paused(), "Pause first");
        require(to != address(0), "Invalid receiver");
        require(amount > 0, "Zero amount");

        uint256 available = unallocatedAXNV();

        require(amount <= available, "Exceeds unallocated AXNV");

        axnv.safeTransfer(to, amount);

        emit UnallocatedAXNVWithdrawn(to, amount);
    }

    function rescueERC20(address token, address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(token != address(axnv), "Use withdrawUnallocatedAXNV");
        require(token != address(0), "Invalid token");
        require(to != address(0), "Invalid receiver");
        require(amount > 0, "Zero amount");

        IERC20(token).safeTransfer(to, amount);

        emit ERC20Rescued(token, to, amount);
    }

    // ------------------------------------------------------------
    // View Functions
    // ------------------------------------------------------------

    function availableRewardPool() public view returns (uint256) {
        uint256 rewardPoolBalance = totalRewardPoolFunded > totalRewardsPaid
            ? totalRewardPoolFunded - totalRewardsPaid
            : 0;

        uint256 balance = axnv.balanceOf(address(this));

        uint256 protectedPrincipalAndPenalties =
            totalStaked + totalPenaltiesCollected;

        if (balance <= protectedPrincipalAndPenalties) {
            return 0;
        }

        uint256 availableByBalance = balance - protectedPrincipalAndPenalties;

        return availableByBalance < rewardPoolBalance
            ? availableByBalance
            : rewardPoolBalance;
    }

    function unallocatedAXNV() public view returns (uint256) {
        uint256 balance = axnv.balanceOf(address(this));

        uint256 rewardPoolBalance = totalRewardPoolFunded > totalRewardsPaid
            ? totalRewardPoolFunded - totalRewardsPaid
            : 0;

        uint256 protectedAmount =
            totalStaked +
            totalPenaltiesCollected +
            rewardPoolBalance;

        if (balance <= protectedAmount) {
            return 0;
        }

        return balance - protectedAmount;
    }

    function requiredAXNVBalance() external view returns (uint256) {
        uint256 rewardPoolBalance = totalRewardPoolFunded > totalRewardsPaid
            ? totalRewardPoolFunded - totalRewardsPaid
            : 0;

        return totalStaked + totalPenaltiesCollected + rewardPoolBalance;
    }

    function contractAXNVBalance() external view returns (uint256) {
        return axnv.balanceOf(address(this));
    }

    function getStake(uint256 stakeId)
        external
        view
        returns (
            address user,
            uint256 amount,
            uint256 startTime,
            uint256 elapsed,
            uint256 accrued,
            uint256 claimedReward,
            uint256 claimable,
            bool withdrawn,
            bool canClaimReward,
            bool earlyPenaltyApplies
        )
    {
        require(stakeId < stakes.length, "Invalid stake");

        StakeInfo memory s = stakes[stakeId];

        user = s.user;
        amount = s.amount;
        startTime = s.startTime;
        elapsed = block.timestamp - s.startTime;
        accrued = accruedReward(stakeId);
        claimedReward = s.rewardClaimed;
        claimable = claimableReward(stakeId);
        withdrawn = s.withdrawn;
        canClaimReward = !s.withdrawn && block.timestamp >= s.startTime + SIX_MONTHS;
        earlyPenaltyApplies = !s.withdrawn && block.timestamp < s.startTime + ONE_MONTH;
    }

    function getUserStakeIds(address user) external view returns (uint256[] memory) {
        return userStakeIds[user];
    }

    function stakesCount() external view returns (uint256) {
        return stakes.length;
    }

    function stakingInfo()
        external
        view
        returns (
            uint256 minStakeAmount,
            uint256 stakedTotal,
            uint256 rewardPoolFunded,
            uint256 rewardsPaid,
            uint256 rewardPoolAvailable,
            uint256 penaltiesCollected,
            uint256 unallocated,
            uint256 contractBalance,
            bool paused_
        )
    {
        minStakeAmount = minStake;
        stakedTotal = totalStaked;
        rewardPoolFunded = totalRewardPoolFunded;
        rewardsPaid = totalRewardsPaid;
        rewardPoolAvailable = availableRewardPool();
        penaltiesCollected = totalPenaltiesCollected;
        unallocated = unallocatedAXNV();
        contractBalance = axnv.balanceOf(address(this));
        paused_ = paused();
    }
}
