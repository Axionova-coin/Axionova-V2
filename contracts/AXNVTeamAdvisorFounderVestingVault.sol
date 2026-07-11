// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AXNVTeamAdvisorFounderVestingVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable axnv;

    uint8 public constant CATEGORY_TEAM = 1;
    uint8 public constant CATEGORY_ADVISORS = 2;
    uint8 public constant CATEGORY_FOUNDER = 3;

    uint256 public constant MONTH = 30 days;

    uint256 public constant TEAM_CAP = 37_500_000 ether;
    uint256 public constant ADVISORS_CAP = 11_250_000 ether;
    uint256 public constant FOUNDER_CAP = 9_350_000 ether;

    uint256 public constant TOTAL_CAP = 58_100_000 ether;

    uint256 public constant TEAM_CLIFF = 12 * MONTH;
    uint256 public constant TEAM_LINEAR = 24 * MONTH;

    uint256 public constant ADVISORS_CLIFF = 6 * MONTH;
    uint256 public constant ADVISORS_LINEAR = 24 * MONTH;

    uint256 public constant FOUNDER_CLIFF = 12 * MONTH;
    uint256 public constant FOUNDER_LINEAR = 48 * MONTH;

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

    constructor(address axnvToken, address initialOwner) Ownable(initialOwner) {
        require(axnvToken != address(0), "Invalid AXNV");
        require(initialOwner != address(0), "Invalid owner");

        axnv = IERC20(axnvToken);
    }

    modifier validCategory(uint8 category) {
        require(
            category == CATEGORY_TEAM ||
                category == CATEGORY_ADVISORS ||
                category == CATEGORY_FOUNDER,
            "Invalid category"
        );
        _;
    }

    function isVestingContract() external pure returns (bool) {
        return true;
    }

    function createSchedule(
        uint8 category,
        address beneficiary,
        uint256 amount,
        uint256 startTime
    ) external onlyOwner validCategory(category) returns (uint256 scheduleId) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Zero amount");
        require(startTime >= block.timestamp, "Past start");

        require(
            categoryAllocated[category] + amount <= categoryCap(category),
            "Category cap exceeded"
        );

        require(totalAllocated + amount <= TOTAL_CAP, "Total cap exceeded");

        categoryAllocated[category] += amount;
        totalAllocated += amount;

        scheduleId = schedules.length;

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

        beneficiaryScheduleIds[beneficiary].push(scheduleId);

        emit ScheduleCreated(
            scheduleId,
            category,
            beneficiary,
            amount,
            startTime
        );
    }

    function createSchedules(
        uint8[] calldata categories,
        address[] calldata beneficiaries,
        uint256[] calldata amounts,
        uint256[] calldata startTimes
    ) external onlyOwner {
        uint256 length = categories.length;

        require(length > 0, "Empty array");
        require(beneficiaries.length == length, "Length mismatch");
        require(amounts.length == length, "Length mismatch");
        require(startTimes.length == length, "Length mismatch");

        for (uint256 i = 0; i < length; i++) {
            _createSchedule(
                categories[i],
                beneficiaries[i],
                amounts[i],
                startTimes[i]
            );
        }
    }

    function _createSchedule(
        uint8 category,
        address beneficiary,
        uint256 amount,
        uint256 startTime
    ) internal validCategory(category) returns (uint256 scheduleId) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Zero amount");
        require(startTime >= block.timestamp, "Past start");

        require(
            categoryAllocated[category] + amount <= categoryCap(category),
            "Category cap exceeded"
        );

        require(totalAllocated + amount <= TOTAL_CAP, "Total cap exceeded");

        categoryAllocated[category] += amount;
        totalAllocated += amount;

        scheduleId = schedules.length;

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

        beneficiaryScheduleIds[beneficiary].push(scheduleId);

        emit ScheduleCreated(
            scheduleId,
            category,
            beneficiary,
            amount,
            startTime
        );
    }

    function changeBeneficiary(
        uint256 scheduleId,
        address newBeneficiary
    ) external onlyOwner {
        require(scheduleId < schedules.length, "Invalid schedule");
        require(newBeneficiary != address(0), "Invalid beneficiary");

        VestingSchedule storage s = schedules[scheduleId];

        require(s.exists, "Schedule missing");

        address oldBeneficiary = s.beneficiary;

        require(oldBeneficiary != newBeneficiary, "Same beneficiary");

        _removeScheduleFromBeneficiary(oldBeneficiary, scheduleId);

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

    function claim(uint256 scheduleId) public nonReentrant {
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
        require(scheduleIds.length > 0, "Empty array");

        uint256 totalAmount;

        for (uint256 i = 0; i < scheduleIds.length; i++) {
            uint256 scheduleId = scheduleIds[i];

            require(scheduleId < schedules.length, "Invalid schedule");

            VestingSchedule storage s = schedules[scheduleId];

            require(s.exists, "Schedule missing");
            require(s.beneficiary == msg.sender, "Not beneficiary");

            uint256 amount = claimable(scheduleId);

            if (amount > 0) {
                s.releasedAmount += amount;
                totalReleased += amount;
                totalAmount += amount;

                emit Claimed(scheduleId, msg.sender, amount);
            }
        }

        require(totalAmount > 0, "Nothing claimable");

        axnv.safeTransfer(msg.sender, totalAmount);
    }

    function claimable(uint256 scheduleId) public view returns (uint256) {
        require(scheduleId < schedules.length, "Invalid schedule");

        VestingSchedule memory s = schedules[scheduleId];

        if (!s.exists) {
            return 0;
        }

        uint256 vested = vestedAmount(scheduleId);

        if (vested <= s.releasedAmount) {
            return 0;
        }

        return vested - s.releasedAmount;
    }

    function vestedAmount(uint256 scheduleId) public view returns (uint256) {
        require(scheduleId < schedules.length, "Invalid schedule");

        VestingSchedule memory s = schedules[scheduleId];

        if (!s.exists) {
            return 0;
        }

        uint256 cliff = categoryCliff(s.category);
        uint256 linear = categoryLinearDuration(s.category);

        if (block.timestamp < s.startTime + cliff) {
            return 0;
        }

        uint256 elapsedAfterCliff = block.timestamp - (s.startTime + cliff);

        if (elapsedAfterCliff >= linear) {
            return s.totalAmount;
        }

        return (s.totalAmount * elapsedAfterCliff) / linear;
    }

    function getSchedule(
        uint256 scheduleId
    )
        external
        view
        returns (
            uint8 category,
            address beneficiary,
            uint256 totalAmount,
            uint256 releasedAmount,
            uint256 startTime,
            uint256 cliffEnd,
            uint256 vestingEnd,
            uint256 vested,
            uint256 claimableAmount_,
            bool exists
        )
    {
        require(scheduleId < schedules.length, "Invalid schedule");

        VestingSchedule memory s = schedules[scheduleId];

        uint256 cliff = categoryCliff(s.category);
        uint256 linear = categoryLinearDuration(s.category);

        category = s.category;
        beneficiary = s.beneficiary;
        totalAmount = s.totalAmount;
        releasedAmount = s.releasedAmount;
        startTime = s.startTime;
        cliffEnd = s.startTime + cliff;
        vestingEnd = s.startTime + cliff + linear;
        vested = vestedAmount(scheduleId);
        claimableAmount_ = claimable(scheduleId);
        exists = s.exists;
    }

    function getBeneficiarySchedules(
        address beneficiary
    ) external view returns (uint256[] memory) {
        return beneficiaryScheduleIds[beneficiary];
    }

    function getBeneficiarySummary(
        address beneficiary
    )
        external
        view
        returns (
            uint256 totalScheduled,
            uint256 totalVested,
            uint256 totalClaimed,
            uint256 totalClaimable,
            uint256 scheduleCount
        )
    {
        uint256[] memory ids = beneficiaryScheduleIds[beneficiary];

        scheduleCount = ids.length;

        for (uint256 i = 0; i < ids.length; i++) {
            VestingSchedule memory s = schedules[ids[i]];

            if (s.exists && s.beneficiary == beneficiary) {
                uint256 vested = vestedAmount(ids[i]);
                uint256 claimableAmount_ = vested > s.releasedAmount
                    ? vested - s.releasedAmount
                    : 0;

                totalScheduled += s.totalAmount;
                totalVested += vested;
                totalClaimed += s.releasedAmount;
                totalClaimable += claimableAmount_;
            }
        }
    }

    function schedulesCount() external view returns (uint256) {
        return schedules.length;
    }

    function categoryCap(uint8 category) public pure returns (uint256) {
        if (category == CATEGORY_TEAM) {
            return TEAM_CAP;
        }

        if (category == CATEGORY_ADVISORS) {
            return ADVISORS_CAP;
        }

        if (category == CATEGORY_FOUNDER) {
            return FOUNDER_CAP;
        }

        revert("Invalid category");
    }

    function categoryCliff(uint8 category) public pure returns (uint256) {
        if (category == CATEGORY_TEAM) {
            return TEAM_CLIFF;
        }

        if (category == CATEGORY_ADVISORS) {
            return ADVISORS_CLIFF;
        }

        if (category == CATEGORY_FOUNDER) {
            return FOUNDER_CLIFF;
        }

        revert("Invalid category");
    }

    function categoryLinearDuration(uint8 category) public pure returns (uint256) {
        if (category == CATEGORY_TEAM) {
            return TEAM_LINEAR;
        }

        if (category == CATEGORY_ADVISORS) {
            return ADVISORS_LINEAR;
        }

        if (category == CATEGORY_FOUNDER) {
            return FOUNDER_LINEAR;
        }

        revert("Invalid category");
    }

    function categoryName(uint8 category) external pure returns (string memory) {
        if (category == CATEGORY_TEAM) {
            return "Team";
        }

        if (category == CATEGORY_ADVISORS) {
            return "Advisors";
        }

        if (category == CATEGORY_FOUNDER) {
            return "Founder";
        }

        revert("Invalid category");
    }

    function reservedAXNV() public view returns (uint256) {
        return totalAllocated - totalReleased;
    }

    function recoverableAXNV() public view returns (uint256) {
        uint256 balance = axnv.balanceOf(address(this));
        uint256 reserved = reservedAXNV();

        if (balance <= reserved) {
            return 0;
        }

        return balance - reserved;
    }

    function contractAXNVBalance() external view returns (uint256) {
        return axnv.balanceOf(address(this));
    }

    function recoverUnallocatedAXNV(
        uint256 amount,
        address to
    ) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid receiver");
        require(amount > 0, "Zero amount");

        uint256 recoverable = recoverableAXNV();

        require(amount <= recoverable, "Exceeds recoverable");

        axnv.safeTransfer(to, amount);

        emit UnallocatedAXNVRecovered(to, amount);
    }

    function rescueERC20(
        address token,
        uint256 amount,
        address to
    ) external onlyOwner nonReentrant {
        require(token != address(axnv), "Use recoverUnallocatedAXNV");
        require(token != address(0), "Invalid token");
        require(to != address(0), "Invalid receiver");
        require(amount > 0, "Zero amount");

        IERC20(token).safeTransfer(to, amount);

        emit ERC20Recovered(token, to, amount);
    }

    function _removeScheduleFromBeneficiary(
        address beneficiary,
        uint256 scheduleId
    ) internal {
        uint256[] storage ids = beneficiaryScheduleIds[beneficiary];

        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == scheduleId) {
                ids[i] = ids[ids.length - 1];
                ids.pop();
                return;
            }
        }
    }
}
