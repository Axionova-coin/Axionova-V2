// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * AXNVMigrator
 * V1 → V2 instant migration (1:1)
 * - 7 day migration window
 * - Hard cap enforced
 * - V1 locked permanently
 * - V2 distributed instantly
 * - Leftover V2 sent to Airdrop contract
 */

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract AXNVMigrator {

    // =========================
    // IMMUTABLE CONFIG
    // =========================
    IERC20 public immutable axnvV1;
    IERC20 public immutable axnvV2;
    address public immutable owner;

    uint256 public constant MIGRATION_DURATION = 7 days;
    uint256 public constant MAX_MIGRATION = 11_250_000 * 1e18;

    address public constant AIRDROP_CONTRACT = 0xB965EDaBc266BC42F07EE2d1aF226f9DAf080DFF;

    // =========================
    // STATE
    // =========================
    bool public migrationStarted;
    uint256 public migrationStart;
    uint256 public migrationEnd;

    uint256 public totalMigrated;
    bool public leftoverSent;

    bool public paused;

    // =========================
    // EVENTS
    // =========================
    event MigrationStarted(uint256 startTime, uint256 endTime);
    event Migrated(address indexed user, uint256 amount);
    event LeftoverSent(uint256 amount);
    event Paused(bool status);

    // =========================
    // MODIFIERS
    // =========================
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier migrationActive() {
        require(migrationStarted, "Not started");
        require(block.timestamp >= migrationStart, "Not live");
        require(block.timestamp <= migrationEnd, "Ended");
        require(!paused, "Paused");
        _;
    }

    // =========================
    // CONSTRUCTOR
    // =========================
    constructor(address _v1, address _v2) {
        require(_v1 != address(0) && _v2 != address(0), "Zero address");

        axnvV1 = IERC20(_v1);
        axnvV2 = IERC20(_v2);
        owner = msg.sender;
    }

    // =========================
    // ADMIN FUNCTIONS
    // =========================

    function startMigration() external onlyOwner {
        require(!migrationStarted, "Already started");

        migrationStarted = true;
        migrationStart = block.timestamp;
        migrationEnd = block.timestamp + MIGRATION_DURATION;

        emit MigrationStarted(migrationStart, migrationEnd);
    }

    function setPaused(bool _status) external onlyOwner {
        paused = _status;
        emit Paused(_status);
    }

    function sendUnclaimedToAirdrop() external onlyOwner {
        require(migrationStarted, "Not started");
        require(block.timestamp > migrationEnd, "Migration not ended");
        require(!leftoverSent, "Already sent");

        uint256 remaining = axnvV2.balanceOf(address(this));
        require(remaining > 0, "No tokens left");

        leftoverSent = true;

        require(axnvV2.transfer(AIRDROP_CONTRACT, remaining), "Transfer failed");

        emit LeftoverSent(remaining);
    }

    // =========================
    // USER FUNCTION
    // =========================

    function migrate(uint256 amount) external migrationActive {
        require(amount > 0, "Zero amount");
        require(totalMigrated + amount <= MAX_MIGRATION, "Cap exceeded");

        // Ensure enough V2 liquidity
        require(
            axnvV2.balanceOf(address(this)) >= amount,
            "Insufficient V2 liquidity"
        );

        // Pull V1
        require(
            axnvV1.transferFrom(msg.sender, address(this), amount),
            "V1 transfer failed"
        );

        // Send V2
        require(
            axnvV2.transfer(msg.sender, amount),
            "V2 transfer failed"
        );

        totalMigrated += amount;

        emit Migrated(msg.sender, amount);
    }

    // =========================
    // SAFETY FUNCTION
    // =========================

    function recoverERC20(address token, uint256 amount) external onlyOwner {
        require(token != address(axnvV1) && token != address(axnvV2), "Not allowed");
        IERC20(token).transfer(owner, amount);
    }
}