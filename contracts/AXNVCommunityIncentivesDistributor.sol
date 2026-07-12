// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AXNVCommunityIncentivesDistributor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable axnv;

    uint256 public constant COMMUNITY_INCENTIVES_CAP = 11_250_000 ether;

    struct Campaign {
        string name;
        uint256 allocation;
        uint256 assigned;
        uint256 claimed;
        bool active;
        bool exists;
    }

    Campaign[] public campaigns;

    mapping(uint256 => mapping(address => uint256)) public rewards;
    mapping(uint256 => mapping(address => bool)) public claimed;

    uint256 public totalFunded;
    uint256 public totalCampaignAllocated;
    uint256 public totalAssigned;
    uint256 public totalClaimed;

    bool public claimsPaused;

    event VaultFunded(address indexed funder, uint256 amount);
    event CampaignCreated(uint256 indexed campaignId, string name, uint256 allocation);
    event CampaignAllocationDecreased(uint256 indexed campaignId, uint256 oldAllocation, uint256 newAllocation);
    event CampaignRemoved(uint256 indexed campaignId, uint256 allocationReturned);
    event RecipientsAdded(uint256 indexed campaignId, uint256 recipientCount, uint256 totalAmount);
    event Claimed(uint256 indexed campaignId, address indexed user, uint256 amount);
    event ClaimsPaused(bool status);
    event CampaignActiveUpdated(uint256 indexed campaignId, bool active);
    event AXNVRecovered(address indexed to, uint256 amount);
    event ERC20Recovered(address indexed token, address indexed to, uint256 amount);

    constructor(address axnvToken, address initialOwner) Ownable(initialOwner) {
        require(axnvToken != address(0), "Invalid AXNV");
        require(initialOwner != address(0), "Invalid owner");
        axnv = IERC20(axnvToken);
    }

    function accountedAXNV() public view returns (uint256) {
        return axnv.balanceOf(address(this)) + totalClaimed;
    }

    function fundVault(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Zero amount");
        require(accountedAXNV() + amount <= COMMUNITY_INCENTIVES_CAP, "Cap exceeded");

        totalFunded += amount;
        axnv.safeTransferFrom(msg.sender, address(this), amount);

        emit VaultFunded(msg.sender, amount);
    }

    function createCampaign(string calldata name, uint256 allocation) external onlyOwner returns (uint256 campaignId) {
        require(bytes(name).length > 0, "Empty name");
        require(allocation > 0, "Zero allocation");
        require(totalCampaignAllocated + allocation <= COMMUNITY_INCENTIVES_CAP, "Cap exceeded");

        campaignId = campaigns.length;

        campaigns.push(Campaign({
            name: name,
            allocation: allocation,
            assigned: 0,
            claimed: 0,
            active: true,
            exists: true
        }));

        totalCampaignAllocated += allocation;

        emit CampaignCreated(campaignId, name, allocation);
    }

    function decreaseCampaignAllocation(uint256 campaignId, uint256 newAllocation) external onlyOwner {
        require(campaignId < campaigns.length, "Invalid campaign");

        Campaign storage c = campaigns[campaignId];
        require(c.exists, "Campaign missing");
        require(newAllocation > 0, "Zero allocation");
        require(newAllocation < c.allocation, "Not decreased");
        require(newAllocation >= c.assigned, "Below assigned");

        uint256 oldAllocation = c.allocation;
        uint256 reduction = oldAllocation - newAllocation;

        c.allocation = newAllocation;
        totalCampaignAllocated -= reduction;

        emit CampaignAllocationDecreased(campaignId, oldAllocation, newAllocation);
    }

    function removeCampaign(uint256 campaignId) external onlyOwner {
        require(campaignId < campaigns.length, "Invalid campaign");

        Campaign storage c = campaigns[campaignId];
        require(c.exists, "Campaign missing");
        require(c.assigned == 0, "Campaign has assigned rewards");
        require(c.claimed == 0, "Campaign has claimed rewards");

        uint256 allocation = c.allocation;

        c.exists = false;
        c.active = false;
        c.allocation = 0;
        totalCampaignAllocated -= allocation;

        emit CampaignRemoved(campaignId, allocation);
    }

    function addRecipients(
        uint256 campaignId,
        address[] calldata wallets,
        uint256[] calldata amounts
    ) external onlyOwner {
        require(campaignId < campaigns.length, "Invalid campaign");
        require(wallets.length == amounts.length, "Length mismatch");
        require(wallets.length > 0, "Empty batch");

        Campaign storage c = campaigns[campaignId];
        require(c.exists, "Campaign missing");

        uint256 totalAmount;

        for (uint256 i = 0; i < wallets.length; i++) {
            address wallet = wallets[i];
            uint256 amount = amounts[i];

            require(wallet != address(0), "Invalid wallet");
            require(amount > 0, "Zero amount");
            require(!claimed[campaignId][wallet], "Already claimed");

            rewards[campaignId][wallet] += amount;
            totalAmount += amount;
        }

        require(c.assigned + totalAmount <= c.allocation, "Campaign allocation exceeded");

        c.assigned += totalAmount;
        totalAssigned += totalAmount;

        emit RecipientsAdded(campaignId, wallets.length, totalAmount);
    }

    function setCampaignActive(uint256 campaignId, bool active) external onlyOwner {
        require(campaignId < campaigns.length, "Invalid campaign");

        Campaign storage c = campaigns[campaignId];
        require(c.exists, "Campaign missing");

        c.active = active;

        emit CampaignActiveUpdated(campaignId, active);
    }

    function setClaimsPaused(bool status) external onlyOwner {
        claimsPaused = status;
        emit ClaimsPaused(status);
    }

    function recoverUnallocatedAXNV(uint256 amount, address to) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");

        uint256 available = unallocatedAXNV();
        require(amount <= available, "Exceeds unallocated");

        axnv.safeTransfer(to, amount);

        emit AXNVRecovered(to, amount);
    }

    function rescueERC20(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        require(token != address(axnv), "Use recoverUnallocatedAXNV");
        require(token != address(0), "Invalid token");
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");

        IERC20(token).safeTransfer(to, amount);

        emit ERC20Recovered(token, to, amount);
    }

    function claim(uint256 campaignId) external nonReentrant {
        require(!claimsPaused, "Claims paused");
        require(campaignId < campaigns.length, "Invalid campaign");

        Campaign storage c = campaigns[campaignId];
        require(c.exists, "Campaign missing");
        require(c.active, "Campaign inactive");
        require(!claimed[campaignId][msg.sender], "Already claimed");

        uint256 amount = rewards[campaignId][msg.sender];
        require(amount > 0, "Nothing claimable");

        claimed[campaignId][msg.sender] = true;

        c.claimed += amount;
        totalClaimed += amount;

        axnv.safeTransfer(msg.sender, amount);

        emit Claimed(campaignId, msg.sender, amount);
    }

    function claimMany(uint256[] calldata campaignIds) external nonReentrant {
        require(!claimsPaused, "Claims paused");
        require(campaignIds.length > 0, "Empty array");

        uint256 totalAmount;

        for (uint256 i = 0; i < campaignIds.length; i++) {
            uint256 campaignId = campaignIds[i];

            require(campaignId < campaigns.length, "Invalid campaign");

            Campaign storage c = campaigns[campaignId];
            require(c.exists, "Campaign missing");
            require(c.active, "Campaign inactive");

            if (claimed[campaignId][msg.sender]) continue;

            uint256 amount = rewards[campaignId][msg.sender];
            if (amount == 0) continue;

            claimed[campaignId][msg.sender] = true;

            c.claimed += amount;
            totalClaimed += amount;
            totalAmount += amount;

            emit Claimed(campaignId, msg.sender, amount);
        }

        require(totalAmount > 0, "Nothing claimable");

        axnv.safeTransfer(msg.sender, totalAmount);
    }

    function getCampaignInfo(uint256 campaignId)
        external
        view
        returns (
            string memory name,
            uint256 allocation,
            uint256 assigned,
            uint256 claimed,
            uint256 remainingAssignable,
            uint256 unclaimedAssigned,
            bool active,
            bool exists
        )
    {
        require(campaignId < campaigns.length, "Invalid campaign");

        Campaign memory c = campaigns[campaignId];

        name = c.name;
        allocation = c.allocation;
        assigned = c.assigned;
        claimed = c.claimed;
        remainingAssignable = c.allocation > c.assigned ? c.allocation - c.assigned : 0;
        unclaimedAssigned = c.assigned > c.claimed ? c.assigned - c.claimed : 0;
        active = c.active;
        exists = c.exists;
    }

    function getUserRewardInfo(uint256 campaignId, address user)
        external
        view
        returns (
            uint256 assignedAmount,
            bool hasClaimed,
            uint256 claimableAmount
        )
    {
        require(campaignId < campaigns.length, "Invalid campaign");

        assignedAmount = rewards[campaignId][user];
        hasClaimed = claimed[campaignId][user];
        claimableAmount = hasClaimed ? 0 : assignedAmount;
    }

    function getAllCampaigns() external view returns (Campaign[] memory) {
        return campaigns;
    }

    function campaignsCount() external view returns (uint256) {
        return campaigns.length;
    }

    function unallocatedAXNV() public view returns (uint256) {
        uint256 balance = axnv.balanceOf(address(this));
        uint256 reserved = totalAssigned > totalClaimed ? totalAssigned - totalClaimed : 0;

        if (balance <= reserved) {
            return 0;
        }

        return balance - reserved;
    }

    function contractAXNVBalance() external view returns (uint256) {
        return axnv.balanceOf(address(this));
    }

    function distributorInfo()
        external
        view
        returns (
            uint256 cap,
            uint256 funded,
            uint256 accounted,
            uint256 campaignAllocated,
            uint256 assigned,
            uint256 claimedTotal,
            uint256 unallocated,
            uint256 balance,
            bool paused
        )
    {
        cap = COMMUNITY_INCENTIVES_CAP;
        funded = totalFunded;
        accounted = accountedAXNV();
        campaignAllocated = totalCampaignAllocated;
        assigned = totalAssigned;
        claimedTotal = totalClaimed;
        unallocated = unallocatedAXNV();
        balance = axnv.balanceOf(address(this));
        paused = claimsPaused;
    }
}
