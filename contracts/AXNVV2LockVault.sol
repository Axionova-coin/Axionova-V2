// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IMigrator {
    function entitled(address user) external view returns (uint256);
    function migrationEnd() external view returns (uint256);
}

contract AXNVV2LockVault {
    IERC20 public immutable axnvV2;
    IMigrator public immutable migrator;
    address public immutable owner;

    uint256 public unlockTime;
    bool public unlockTimeSet;

    mapping(address => bool) public claimed;

    event UnlockTimeSet(uint256 unlockTime);
    event Claimed(address indexed user, uint256 amount);
    event AirdropTransferred(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier afterUnlock() {
        require(unlockTimeSet, "Unlock not set");
        require(block.timestamp >= unlockTime, "Still locked");
        _;
    }

    constructor(
        address _axnvV2,
        address _migrator,
        address _owner
    ) {
        axnvV2 = IERC20(_axnvV2);
        migrator = IMigrator(_migrator);
        owner = _owner;
    }

    /// @notice Set unlock time (TGE + 7 days). Callable once.
    function setUnlockTime(uint256 _unlockTime) external onlyOwner {
        require(!unlockTimeSet, "Unlock already set");
        require(_unlockTime > block.timestamp, "Must be future");

        unlockTime = _unlockTime;
        unlockTimeSet = true;

        emit UnlockTimeSet(_unlockTime);
    }

    /// @notice Claim migrated V2 after migration is finished AND unlock passed
    function claim() external afterUnlock {
        require(
            block.timestamp >= migrator.migrationEnd(),
            "Migration not finished"
        );
        require(!claimed[msg.sender], "Already claimed");

        uint256 amount = migrator.entitled(msg.sender);
        require(amount > 0, "No entitlement");

        claimed[msg.sender] = true;

        require(
            axnvV2.transfer(msg.sender, amount),
            "V2 transfer failed"
        );

        emit Claimed(msg.sender, amount);
    }

    /// @notice Manual V2 airdrop transfers (after unlock)
    function transferAirdrop(address to, uint256 amount)
        external
        onlyOwner
        afterUnlock
    {
        require(to != address(0), "Zero address");
        require(amount > 0, "Amount zero");

        require(
            axnvV2.transfer(to, amount),
            "V2 transfer failed"
        );

        emit AirdropTransferred(to, amount);
    }
}
