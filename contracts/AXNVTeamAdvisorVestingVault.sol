// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AXNVTeamAdvisorVestingVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable axnv;

    uint256 public constant MONTH = 30 days;

    uint8 public constant CATEGORY_TEAM = 1;
    uint8 public constant CATEGORY_ADVISORS = 2;

    uint256 public constant TEAM_CAP = 45_000_000 ether;
    uint256 public constant ADVISORS_CAP = 15_000_000 ether;
    uint256 public constant TOTAL_CAP = 60_000_000 ether;

    uint256 public constant TEAM_CLIFF = 12 * MONTH;
    uint256 public constant TEAM_LINEAR = 24 * MONTH;

    uint256 public constant ADVISORS_CLIFF = 6 * MONTH;
    uint256 public constant ADVISORS_LINEAR = 24 * MONTH;

    bool public claimsPaused;

    uint256 public totalAllocated;
    uint256 public totalReleased;

    mapping(uint8 => uint256) public categoryAllocated;

    struct VestingSchedule {
        uint8 category;
        address beneficiary;
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        bool exists;
    }

    VestingSchedule[] public schedules;
    mapping(address => uint256[]) private beneficiaryScheduleIds;

    event ScheduleCreated(
        uint256 indexed scheduleId,
        uint8 indexed category,
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime
    );

    event BeneficiaryChanged(
        uint256 indexed scheduleId,
        address indexed oldBeneficiary,
        address indexed newBeneficiary
    );

    event Claimed(
        uint256 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount
    );

    event VaultFunded(address indexed funder, uint256 amount);
    event ClaimsPaused(bool status);
    event UnallocatedAXNVRecovered(address indexed to, uint256 amount);
    event ERC20Recovered(address indexed token, address indexed to, uint256 amount);

    modifier validCategory(uint8 category) {
        require(
            category == CATEGORY_TEAM || category == CATEGORY_ADVISORS,
            "Invalid category"
        );
        _;
    }

    constructor(address _axnv) Ownable(msg.sender) {
        require(_axnv != address(0), "Invalid AXNV");
        axnv = IERC20(_axnv);
    }

    function isVestingContract() external pure returns (bool) {
        return true;
    }

    function createSchedule(
        uint8 category,
        address beneficiary,
        uint256 amount,
        uint256 startTime
    ) external onlyOwner validCategory(category) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Zero amount");
        require(startTime >= block.timestamp, "Past start");

        require(categoryAllocated[category] + amount <= categoryCap(category), "Category cap exceeded");
        require(totalAllocated + amount <= TOTAL_CAP, "Total cap exceeded");

        categoryAllocated[category] += amount;
        totalAllocated += amount;

        schedules.push(
            VestingSchedule({
                category: category,
                beneficiary: beneficiary,
                totalAmount: amount,
                releasedAmount: 0,
                startTime: startTime,
                exists: true
            })
        );

        uint256 scheduleId = schedules.length - 1;
        beneficiaryScheduleIds[beneficiary].push(scheduleId);

        emit ScheduleCreated(scheduleId, category, beneficiary, amount, startTime);
    }

    function changeBeneficiary(uint256 scheduleId, address newBeneficiary) external onlyOwner {
        require(scheduleId < schedules.length, "Invalid schedule");
        require(newBeneficiary != address(0), "Invalid beneficiary");

        VestingSchedule storage s = schedules[scheduleId];
        require(s.exists, "Schedule missing");
        require(block.timestamp < s.startTime, "Schedule already started");

        address oldBeneficiary = s.beneficiary;
        require(oldBeneficiary != newBeneficiary, "Same beneficiary");

        s.beneficiary = newBeneficiary;
        beneficiaryScheduleIds[newBeneficiary].push(scheduleId);

        emit BeneficiaryChanged(scheduleId, oldBeneficiary, newBeneficiary);
    }

    function fundVault(uint256 amount) external onlyOwner {
        require(amount > 0, "Zero amount");

        axnv.safeTransferFrom(msg.sender, address(this), amount);

        emit VaultFunded(msg.sender, amount);
    }

    function setClaimsPaused(bool status) external onlyOwner {
        claimsPaused = status;

        emit ClaimsPaused(status);
    }

    function claim(uint256 scheduleId) external nonReentrant {
        require(!claimsPaused, "Claims paused");
        require(scheduleId < schedules.length, "Invalid schedule");

        VestingSchedule storage s = schedules[scheduleId];

        require(s.exists, "Schedule missing");
        require(s.beneficiary == msg.sender, "Not beneficiary");

        uint256 amount = claimable(scheduleId);
        require(amount > 0, "Nothing claimable");

        s.releasedAmount += amount;
        totalReleased += amount;

        axnv.safeTransfer(msg.sender, amount);

        emit Claimed(scheduleId, msg.sender, amount);
    }

    function claimMany(uint256[] calldata scheduleIds) external nonReentrant {
        require(!claimsPaused, "Claims paused");

        uint256 totalClaimAmount;

        for (uint256 i = 0; i < scheduleIds.length; i++) {
            uint256 scheduleId = scheduleIds[i];

            require(scheduleId < schedules.length, "Invalid schedule");

            VestingSchedule storage s = schedules[scheduleId];

            require(s.exists, "Schedule missing");
            require(s.beneficiary == msg.sender, "Not beneficiary");

            uint256 amount = _claimable(s);

            if (amount > 0) {
                s.releasedAmount += amount;
                totalReleased += amount;
                totalClaimAmount += amount;

                emit Claimed(scheduleId, msg.sender, amount);
            }
        }

        require(totalClaimAmount > 0, "Nothing claimable");

        axnv.safeTransfer(msg.sender, totalClaimAmount);
    }

    function recoverUnallocatedAXNV(uint256 amount, address to) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid recipient");

        uint256 recoverable = unallocatedAXNV();
        require(amount <= recoverable, "Exceeds unallocated");

        axnv.safeTransfer(to, amount);

        emit UnallocatedAXNVRecovered(to, amount);
    }

    function rescueERC20(address token, uint256 amount, address to) external onlyOwner nonReentrant {
        require(token != address(axnv), "Use recoverUnallocatedAXNV");
        require(to != address(0), "Invalid recipient");

        IERC20(token).safeTransfer(to, amount);

        emit ERC20Recovered(token, to, amount);
    }

    function claimable(uint256 scheduleId) public view returns (uint256) {
        require(scheduleId < schedules.length, "Invalid schedule");
        return _claimable(schedules[scheduleId]);
    }

    function vestedAmount(uint256 scheduleId) public view returns (uint256) {
        require(scheduleId < schedules.length, "Invalid schedule");
        return _vestedAmount(schedules[scheduleId]);
    }

    function _claimable(VestingSchedule memory s) internal view returns (uint256) {
        uint256 vested = _vestedAmount(s);

        if (vested <= s.releasedAmount) {
            return 0;
        }

        return vested - s.releasedAmount;
    }

    function _vestedAmount(VestingSchedule memory s) internal view returns (uint256) {
        if (block.timestamp < s.startTime) {
            return 0;
        }

        (uint256 cliffDuration, uint256 linearDuration) = categoryDurations(s.category);

        uint256 cliffEnd = s.startTime + cliffDuration;
        uint256 vestingEnd = cliffEnd + linearDuration;

        if (block.timestamp < cliffEnd) {
            return 0;
        }

        if (block.timestamp >= vestingEnd) {
            return s.totalAmount;
        }

        uint256 elapsed = block.timestamp - cliffEnd;

        return (s.totalAmount * elapsed) / linearDuration;
    }

    function categoryCap(uint8 category) public pure returns (uint256) {
        if (category == CATEGORY_TEAM) return TEAM_CAP;
        if (category == CATEGORY_ADVISORS) return ADVISORS_CAP;

        revert("Invalid category");
    }

    function categoryDurations(uint8 category) public pure returns (
        uint256 cliffDuration,
        uint256 linearDuration
    ) {
        if (category == CATEGORY_TEAM) return (TEAM_CLIFF, TEAM_LINEAR);
        if (category == CATEGORY_ADVISORS) return (ADVISORS_CLIFF, ADVISORS_LINEAR);

        revert("Invalid category");
    }

    function beneficiarySchedules(address beneficiary) external view returns (uint256[] memory) {
        return beneficiaryScheduleIds[beneficiary];
    }

    function schedulesCount() external view returns (uint256) {
        return schedules.length;
    }

    function outstandingAllocatedAXNV() public view returns (uint256) {
        return totalAllocated - totalReleased;
    }

    function contractAXNVBalance() public view returns (uint256) {
        return axnv.balanceOf(address(this));
    }

    function unallocatedAXNV() public view returns (uint256) {
        uint256 balance = axnv.balanceOf(address(this));
        uint256 outstanding = outstandingAllocatedAXNV();

        if (balance <= outstanding) {
            return 0;
        }

        return balance - outstanding;
    }

    function remainingCategoryAllocation(uint8 category) external view returns (uint256) {
        return categoryCap(category) - categoryAllocated[category];
    }

    function getSchedule(uint256 scheduleId) external view returns (
        uint8 category,
        address beneficiary,
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 startTime,
        uint256 cliffEnd,
        uint256 vestingEnd,
        uint256 claimableAmount
    ) {
        require(scheduleId < schedules.length, "Invalid schedule");

        VestingSchedule memory s = schedules[scheduleId];

        (uint256 cliffDuration, uint256 linearDuration) = categoryDurations(s.category);

        return (
            s.category,
            s.beneficiary,
            s.totalAmount,
            s.releasedAmount,
            s.startTime,
            s.startTime + cliffDuration,
            s.startTime + cliffDuration + linearDuration,
            _claimable(s)
        );
    }
}
