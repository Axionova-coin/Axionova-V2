// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AXNVLiquidityAllocationVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable axnv;
    address public immutable liquidityManager;

    uint256 public constant LIQUIDITY_ALLOCATION_CAP = 52_500_000 ether;

    uint256 public totalReleased;
    bool public releasePaused;

    event VaultFunded(address indexed funder, uint256 amount);
    event LiquidityReleased(address indexed liquidityManager, uint256 amount);
    event ReleasePaused(bool status);
    event ExcessAXNVRecovered(address indexed to, uint256 amount);
    event ERC20Recovered(address indexed token, address indexed to, uint256 amount);

    constructor(address _axnv, address _liquidityManager) Ownable(msg.sender) {
        require(_axnv != address(0), "Invalid AXNV");
        require(_liquidityManager != address(0), "Invalid manager");

        axnv = IERC20(_axnv);
        liquidityManager = _liquidityManager;
    }

    function isLiquidityAllocationVault() external pure returns (bool) {
        return true;
    }

    function fundVault(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Zero amount");
        require(accountedAXNV() + amount <= LIQUIDITY_ALLOCATION_CAP, "Cap exceeded");

        axnv.safeTransferFrom(msg.sender, address(this), amount);

        emit VaultFunded(msg.sender, amount);
    }

    function releaseLiquidityAXNV(uint256 amount) external onlyOwner nonReentrant {
        require(!releasePaused, "Release paused");
        require(amount > 0, "Zero amount");
        require(totalReleased + amount <= LIQUIDITY_ALLOCATION_CAP, "Release cap exceeded");
        require(amount <= contractAXNVBalance(), "Insufficient AXNV");

        totalReleased += amount;

        axnv.safeTransfer(liquidityManager, amount);

        emit LiquidityReleased(liquidityManager, amount);
    }

    function setReleasePaused(bool status) external onlyOwner {
        releasePaused = status;

        emit ReleasePaused(status);
    }

    function recoverExcessAXNV(uint256 amount, address to) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid recipient");

        uint256 excess = excessAXNV();
        require(amount <= excess, "Exceeds excess");

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

    function contractAXNVBalance() public view returns (uint256) {
        return axnv.balanceOf(address(this));
    }

    function accountedAXNV() public view returns (uint256) {
        return contractAXNVBalance() + totalReleased;
    }

    function remainingAllocation() external view returns (uint256) {
        uint256 accounted = accountedAXNV();

        if (accounted >= LIQUIDITY_ALLOCATION_CAP) {
            return 0;
        }

        return LIQUIDITY_ALLOCATION_CAP - accounted;
    }

    function remainingReleasable() external view returns (uint256) {
        return LIQUIDITY_ALLOCATION_CAP - totalReleased;
    }

    function excessAXNV() public view returns (uint256) {
        uint256 balance = contractAXNVBalance();
        uint256 requiredRemaining = LIQUIDITY_ALLOCATION_CAP - totalReleased;

        if (balance <= requiredRemaining) {
            return 0;
        }

        return balance - requiredRemaining;
    }
}
