// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGameIncentivesVault {
    function emitRewards(address to, uint256 amount) external;
    function currentEpoch() external view returns (uint256);
}

contract GameRewardsAccrual {
    address public owner;
    IGameIncentivesVault public vault;

    mapping(address => uint256) public unclaimedRewards;
    mapping(uint256 => bool) public epochFinalized;

    event RewardsAccrued(uint256 indexed epoch, address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event OwnershipTransferred(address oldOwner, address newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(address _vault) {
        owner = msg.sender;
        vault = IGameIncentivesVault(_vault);
    }

    /**
     * @notice Called by game logic (off-chain or on-chain) to record rent.
     * Epoch-finalized: once an epoch is closed, it can’t be changed.
     */
    function accrueRewards(
        uint256 epoch,
        address[] calldata users,
        uint256[] calldata amounts
    ) external onlyOwner {
        require(!epochFinalized[epoch], "EPOCH_FINALIZED");
        require(users.length == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < users.length; i++) {
            unclaimedRewards[users[i]] += amounts[i];
            emit RewardsAccrued(epoch, users[i], amounts[i]);
        }
    }

    function finalizeEpoch(uint256 epoch) external onlyOwner {
        epochFinalized[epoch] = true;
    }

    /**
     * @notice User pulls accumulated rewards in a single tx.
     */
    function claim() external {
        uint256 amount = unclaimedRewards[msg.sender];
        require(amount > 0, "NOTHING_TO_CLAIM");

        unclaimedRewards[msg.sender] = 0;
        vault.emitRewards(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_ADDRESS");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
