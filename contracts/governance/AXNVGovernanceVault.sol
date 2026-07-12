// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AXNVGovernanceVault is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable axnv;

    uint256 public constant GOVERNANCE_ALLOCATION_CAP = 11_250_000 ether;

    uint256 public totalReleased;

    event VaultFunded(address indexed funder, uint256 amount);
    event GovernanceAXNVReleased(address indexed to, uint256 amount, string purpose);
    event ExcessAXNVRecovered(address indexed to, uint256 amount);
    event ERC20Recovered(address indexed token, address indexed to, uint256 amount);

    constructor(address axnvToken, address initialOwner) Ownable(initialOwner) {
        require(axnvToken != address(0), "Invalid AXNV");
        require(initialOwner != address(0), "Invalid owner");

        axnv = IERC20(axnvToken);
    }

    function fundVault(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Zero amount");

        uint256 newAccounted = accountedAXNV() + amount;
        require(newAccounted <= GOVERNANCE_ALLOCATION_CAP, "Cap exceeded");

        axnv.safeTransferFrom(msg.sender, address(this), amount);

        emit VaultFunded(msg.sender, amount);
    }

    function releaseGovernanceAXNV(
        address to,
        uint256 amount,
        string calldata purpose
    )
        external
        onlyOwner
        nonReentrant
        whenNotPaused
    {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");
        require(totalReleased + amount <= GOVERNANCE_ALLOCATION_CAP, "Cap exceeded");
        require(amount <= contractAXNVBalance(), "Insufficient AXNV");

        totalReleased += amount;

        axnv.safeTransfer(to, amount);

        emit GovernanceAXNVReleased(to, amount, purpose);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function recoverExcessAXNV(address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");

        uint256 excess = excessAXNV();
        require(amount <= excess, "Exceeds excess");

        axnv.safeTransfer(to, amount);

        emit ExcessAXNVRecovered(to, amount);
    }

    function rescueERC20(address token, address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(token != address(axnv), "Use recoverExcessAXNV");
        require(token != address(0), "Invalid token");
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");

        IERC20(token).safeTransfer(to, amount);

        emit ERC20Recovered(token, to, amount);
    }

    function contractAXNVBalance() public view returns (uint256) {
        return axnv.balanceOf(address(this));
    }

    function accountedAXNV() public view returns (uint256) {
        return contractAXNVBalance() + totalReleased;
    }

    function remainingAllocation() public view returns (uint256) {
        uint256 accounted = accountedAXNV();

        if (accounted >= GOVERNANCE_ALLOCATION_CAP) {
            return 0;
        }

        return GOVERNANCE_ALLOCATION_CAP - accounted;
    }

    function remainingReleasable() public view returns (uint256) {
        if (totalReleased >= GOVERNANCE_ALLOCATION_CAP) {
            return 0;
        }

        return GOVERNANCE_ALLOCATION_CAP - totalReleased;
    }

    function excessAXNV() public view returns (uint256) {
        uint256 balance = contractAXNVBalance();

        uint256 requiredRemaining = totalReleased >= GOVERNANCE_ALLOCATION_CAP
            ? 0
            : GOVERNANCE_ALLOCATION_CAP - totalReleased;

        if (balance <= requiredRemaining) {
            return 0;
        }

        return balance - requiredRemaining;
    }

    function vaultInfo()
        external
        view
        returns (
            address axnvToken,
            uint256 allocationCap,
            uint256 released,
            uint256 balance,
            uint256 accounted,
            uint256 remaining,
            uint256 releasableRemaining,
            uint256 excess,
            bool paused_
        )
    {
        axnvToken = address(axnv);
        allocationCap = GOVERNANCE_ALLOCATION_CAP;
        released = totalReleased;
        balance = contractAXNVBalance();
        accounted = accountedAXNV();
        remaining = remainingAllocation();
        releasableRemaining = remainingReleasable();
        excess = excessAXNV();
        paused_ = paused();
    }
}
