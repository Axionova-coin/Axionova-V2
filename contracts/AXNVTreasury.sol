// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AXNVTreasury is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable axnv;

    uint8 public constant CATEGORY_ECOSYSTEM_DEVELOPMENT = 1;
    uint8 public constant CATEGORY_MARKETING_CEXS = 2;
    uint8 public constant CATEGORY_BUG_BOUNTY = 3;
    uint8 public constant CATEGORY_CHARITY_SOCIAL_IMPACT = 4;

    uint256 public constant ECOSYSTEM_DEVELOPMENT_CAP = 42_900_000 ether;
    uint256 public constant MARKETING_CEXS_CAP = 22_500_000 ether;
    uint256 public constant BUG_BOUNTY_CAP = 7_500_000 ether;
    uint256 public constant CHARITY_SOCIAL_IMPACT_CAP = 7_500_000 ether;

    uint256 public constant TOTAL_TREASURY_CAP = 80_400_000 ether;

    uint256 public totalSpent;

    mapping(uint8 => uint256) public categorySpent;

    event TreasuryFunded(address indexed from, uint256 amount);

    event TreasurySpent(
        uint8 indexed category,
        address indexed to,
        uint256 amount,
        string purpose
    );

    event AXNVRecovered(address indexed to, uint256 amount);
    event ERC20Recovered(address indexed token, address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error InvalidCategory();
    error CategoryCapExceeded();
    error TotalCapExceeded();
    error InsufficientBalance();

    constructor(address axnvToken, address initialOwner) Ownable(initialOwner) {
        if (axnvToken == address(0)) revert ZeroAddress();
        if (initialOwner == address(0)) revert ZeroAddress();

        axnv = IERC20(axnvToken);
    }

    modifier validCategory(uint8 category) {
        if (
            category != CATEGORY_ECOSYSTEM_DEVELOPMENT &&
            category != CATEGORY_MARKETING_CEXS &&
            category != CATEGORY_BUG_BOUNTY &&
            category != CATEGORY_CHARITY_SOCIAL_IMPACT
        ) {
            revert InvalidCategory();
        }

        _;
    }

    function fundTreasury(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();

        axnv.safeTransferFrom(msg.sender, address(this), amount);

        emit TreasuryFunded(msg.sender, amount);
    }

    function spend(
        uint8 category,
        address to,
        uint256 amount,
        string calldata purpose
    ) external onlyOwner nonReentrant whenNotPaused validCategory(category) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        if (categorySpent[category] + amount > categoryCap(category)) {
            revert CategoryCapExceeded();
        }

        if (totalSpent + amount > TOTAL_TREASURY_CAP) {
            revert TotalCapExceeded();
        }

        if (axnv.balanceOf(address(this)) < amount) {
            revert InsufficientBalance();
        }

        categorySpent[category] += amount;
        totalSpent += amount;

        axnv.safeTransfer(to, amount);

        emit TreasurySpent(category, to, amount, purpose);
    }

    function spendBatch(
        uint8[] calldata categories,
        address[] calldata recipients,
        uint256[] calldata amounts,
        string[] calldata purposes
    ) external onlyOwner nonReentrant whenNotPaused {
        uint256 length = categories.length;

        require(length > 0, "Empty batch");
        require(recipients.length == length, "Recipients length mismatch");
        require(amounts.length == length, "Amounts length mismatch");
        require(purposes.length == length, "Purposes length mismatch");

        uint256 batchTotal;

        for (uint256 i = 0; i < length; i++) {
            uint8 category = categories[i];
            address to = recipients[i];
            uint256 amount = amounts[i];

            if (
                category != CATEGORY_ECOSYSTEM_DEVELOPMENT &&
                category != CATEGORY_MARKETING_CEXS &&
                category != CATEGORY_BUG_BOUNTY &&
                category != CATEGORY_CHARITY_SOCIAL_IMPACT
            ) {
                revert InvalidCategory();
            }

            if (to == address(0)) revert ZeroAddress();
            if (amount == 0) revert ZeroAmount();

            if (categorySpent[category] + amount > categoryCap(category)) {
                revert CategoryCapExceeded();
            }

            categorySpent[category] += amount;
            batchTotal += amount;
        }

        if (totalSpent + batchTotal > TOTAL_TREASURY_CAP) {
            revert TotalCapExceeded();
        }

        if (axnv.balanceOf(address(this)) < batchTotal) {
            revert InsufficientBalance();
        }

        totalSpent += batchTotal;

        for (uint256 i = 0; i < length; i++) {
            axnv.safeTransfer(recipients[i], amounts[i]);

            emit TreasurySpent(
                categories[i],
                recipients[i],
                amounts[i],
                purposes[i]
            );
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function categoryCap(uint8 category) public pure returns (uint256) {
        if (category == CATEGORY_ECOSYSTEM_DEVELOPMENT) {
            return ECOSYSTEM_DEVELOPMENT_CAP;
        }

        if (category == CATEGORY_MARKETING_CEXS) {
            return MARKETING_CEXS_CAP;
        }

        if (category == CATEGORY_BUG_BOUNTY) {
            return BUG_BOUNTY_CAP;
        }

        if (category == CATEGORY_CHARITY_SOCIAL_IMPACT) {
            return CHARITY_SOCIAL_IMPACT_CAP;
        }

        revert InvalidCategory();
    }

    function categoryRemaining(uint8 category) public view returns (uint256) {
        uint256 cap = categoryCap(category);
        uint256 spent = categorySpent[category];

        if (spent >= cap) {
            return 0;
        }

        return cap - spent;
    }

    function categoryName(uint8 category) external pure returns (string memory) {
        if (category == CATEGORY_ECOSYSTEM_DEVELOPMENT) {
            return "Ecosystem Development";
        }

        if (category == CATEGORY_MARKETING_CEXS) {
            return "Marketing / CEXs";
        }

        if (category == CATEGORY_BUG_BOUNTY) {
            return "Bug Bounty";
        }

        if (category == CATEGORY_CHARITY_SOCIAL_IMPACT) {
            return "Charity / Social Impact";
        }

        revert InvalidCategory();
    }

    function treasuryInfo()
        external
        view
        returns (
            uint256 totalCap,
            uint256 spentTotal,
            uint256 remainingTotal,
            uint256 contractBalance,
            bool paused_
        )
    {
        totalCap = TOTAL_TREASURY_CAP;
        spentTotal = totalSpent;
        remainingTotal = totalSpent >= TOTAL_TREASURY_CAP
            ? 0
            : TOTAL_TREASURY_CAP - totalSpent;
        contractBalance = axnv.balanceOf(address(this));
        paused_ = paused();
    }

    function categoryInfo(uint8 category)
        external
        view
        returns (
            string memory name,
            uint256 cap,
            uint256 spent,
            uint256 remaining
        )
    {
        cap = categoryCap(category);
        spent = categorySpent[category];
        remaining = categoryRemaining(category);

        if (category == CATEGORY_ECOSYSTEM_DEVELOPMENT) {
            name = "Ecosystem Development";
        } else if (category == CATEGORY_MARKETING_CEXS) {
            name = "Marketing / CEXs";
        } else if (category == CATEGORY_BUG_BOUNTY) {
            name = "Bug Bounty";
        } else if (category == CATEGORY_CHARITY_SOCIAL_IMPACT) {
            name = "Charity / Social Impact";
        } else {
            revert InvalidCategory();
        }
    }

    function contractAXNVBalance() external view returns (uint256) {
        return axnv.balanceOf(address(this));
    }

    function recoverableAXNV() public view returns (uint256) {
        uint256 balance = axnv.balanceOf(address(this));
        uint256 remainingCap = totalSpent >= TOTAL_TREASURY_CAP
            ? 0
            : TOTAL_TREASURY_CAP - totalSpent;

        if (balance <= remainingCap) {
            return 0;
        }

        return balance - remainingCap;
    }

    function recoverExcessAXNV(address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 recoverable = recoverableAXNV();

        require(amount <= recoverable, "Exceeds recoverable AXNV");

        axnv.safeTransfer(to, amount);

        emit AXNVRecovered(to, amount);
    }

    function rescueERC20(address token, address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        if (token == address(0)) revert ZeroAddress();
        if (token == address(axnv)) {
            revert("Use recoverExcessAXNV");
        }
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        IERC20(token).safeTransfer(to, amount);

        emit ERC20Recovered(token, to, amount);
    }
}
