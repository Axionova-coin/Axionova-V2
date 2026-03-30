// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CommunityIncentivesDistributor {
    IERC20 public immutable axnv;
    address public owner;

    mapping(address => uint256) public allocated;
    uint256 public totalAllocated;

    event RewardsAllocated(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event OwnerTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _axnv, address _owner) {
        require(_axnv != address(0), "AXNV zero");
        require(_owner != address(0), "Owner zero");
        axnv = IERC20(_axnv);
        owner = _owner;
    }

    function allocate(address user, uint256 amount) external onlyOwner {
        require(user != address(0), "User zero");
        require(amount > 0, "Zero amount");

        uint256 available =
            axnv.balanceOf(address(this)) - totalAllocated;

        require(amount <= available, "Insufficient pool");

        allocated[user] += amount;
        totalAllocated += amount;

        emit RewardsAllocated(user, amount);
    }

    function claim() external {
        uint256 amount = allocated[msg.sender];
        require(amount > 0, "Nothing to claim");

        allocated[msg.sender] = 0;
        totalAllocated -= amount;

        require(axnv.transfer(msg.sender, amount), "Transfer failed");

        emit RewardsClaimed(msg.sender, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Owner zero");
        emit OwnerTransferred(owner, newOwner);
        owner = newOwner;
    }
}
