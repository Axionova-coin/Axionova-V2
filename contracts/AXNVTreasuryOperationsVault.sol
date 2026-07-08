// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AXNVTreasuryOperationsVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable axnv;

    uint8 public constant CATEGORY_MARKETING_CEX = 1;
    uint8 public constant CATEGORY_ECOSYSTEM = 2;
    uint8 public constant CATEGORY_BUG_BOUNTY = 3;
    uint8 public constant CATEGORY_CHARITY = 4;

    uint256 public constant MARKETING_CEX_CAP = 22_500_000 ether;
    uint256 public constant ECOSYSTEM_CAP = 60_000_000 ether;
    uint256 public constant BUG_BOUNTY_CAP = 7_500_000 ether;
    uint256 public constant CHARITY_CAP = 7_500_000 ether;
    uint256 public constant TOTAL_CAP = 97_500_000 ether;

    bool public releasePaused;

    uint256 public totalFunded;
    uint256 public totalReleased;

    mapping(uint8 => uint256) public categoryFunded;
    mapping(uint8 => uint256) public categoryReleased;

    event VaultFunded(uint8 indexed category, address indexed funder, uint256 amount);
    event AXNVReleased(uint8 indexed category, address indexed to, uint256 amount, string purpose);
    event ReleasePaused(bool status);
    event ExcessAXNVRecovered(address indexed to, uint256 amount);
    event ERC20Recovered(address indexed token, address indexed to, uint256 amount);

    modifier validCategory(uint8 category) {
        require(
            category == CATEGORY_MARKETING_CEX ||
            category == CATEGORY_ECOSYSTEM ||
            category == CATEGORY_BUG_BOUNTY ||
            category == CATEGORY_CHARITY,
            "Invalid category"
        );
        _;
    }

    constructor(address _axnv) Ownable(msg.sender) {
        require(_axnv != address(0), "Invalid AXNV");
        axnv = IERC20(_axnv);
    }

    function isTreasuryOperationsVault() external pure returns (bool) {
        return true;
    }

    function fundVault(uint8 category, uint256 amount) external onlyOwner nonReentrant validCategory(category) {
        require(amount > 0, "Zero amount");
        require(categoryFunded[category] + amount <= categoryCap(category), "Category cap exceeded");
        require(totalFunded + amount <= TOTAL_CAP, "Total cap exceeded");

        categoryFunded[category] += amount;
        totalFunded += amount;

        axnv.safeTransferFrom(msg.sender, address(this), amount);

        emit VaultFunded(category, msg.sender, amount);
    }

    function releaseAXNV(
        uint8 category,
        address to,
        uint256 amount,
        string calldata purpose
    ) external onlyOwner nonReentrant validCategory(category) {
        require(!releasePaused, "Release paused");
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");
        require(amount <= categoryBalance(category), "Insufficient category balance");

        categoryReleased[category] += amount;
        totalReleased += amount;

        axnv.safeTransfer(to, amount);

        emit AXNVReleased(category, to, amount, purpose);
    }

    function setReleasePaused(bool status) external onlyOwner {
        releasePaused = status;
        emit ReleasePaused(status);
    }

    function recoverExcessAXNV(uint256 amount, address to) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");
        require(amount <= excessAXNV(), "Exceeds excess");

        axnv.safeTransfer(to, amount);

        emit ExcessAXNVRecovered(to, amount);
    }

    function rescueERC20(address token, uint256 amount, address to) external onlyOwner nonReentrant {
        require(token != address(axnv), "Use recoverExcessAXNV");
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");

        IERC20(token).safeTransfer(to, amount);

        emit ERC20Recovered(token, to, amount);
    }

    function categoryCap(uint8 category) public pure returns (uint256) {
        if (category == CATEGORY_MARKETING_CEX) return MARKETING_CEX_CAP;
        if (category == CATEGORY_ECOSYSTEM) return ECOSYSTEM_CAP;
        if (category == CATEGORY_BUG_BOUNTY) return BUG_BOUNTY_CAP;
        if (category == CATEGORY_CHARITY) return CHARITY_CAP;

        revert("Invalid category");
    }

    function categoryBalance(uint8 category) public view validCategory(category) returns (uint256) {
        return categoryFunded[category] - categoryReleased[category];
    }

    function remainingCategoryFundable(uint8 category) external view validCategory(category) returns (uint256) {
        return categoryCap(category) - categoryFunded[category];
    }

    function contractAXNVBalance() public view returns (uint256) {
        return axnv.balanceOf(address(this));
    }

    function accountedAXNV() public view returns (uint256) {
        uint256 requiredBalance = totalFunded - totalReleased;
        return requiredBalance;
    }

    function excessAXNV() public view returns (uint256) {
        uint256 balance = contractAXNVBalance();
        uint256 required = accountedAXNV();

        if (balance <= required) {
            return 0;
        }

        return balance - required;
    }
}
