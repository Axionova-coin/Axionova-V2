// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AXNVReserveVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable axnv;

    uint256 public totalFunded;
    uint256 public totalReleased;

    event VaultFunded(address indexed funder, uint256 amount);
    event AXNVReleased(address indexed to, uint256 amount, string purpose);
    event ERC20Recovered(address indexed token, address indexed to, uint256 amount);

    constructor(address axnvToken, address initialOwner) Ownable(initialOwner) {
        require(axnvToken != address(0), "Invalid AXNV");
        require(initialOwner != address(0), "Invalid owner");

        axnv = IERC20(axnvToken);
    }

    function isReserveVault() external pure returns (bool) {
        return true;
    }

    function fundVault(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Zero amount");

        totalFunded += amount;

        axnv.safeTransferFrom(msg.sender, address(this), amount);

        emit VaultFunded(msg.sender, amount);
    }

    function releaseAXNV(
        address to,
        uint256 amount,
        string calldata purpose
    ) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");
        require(amount <= axnv.balanceOf(address(this)), "Insufficient AXNV");

        totalReleased += amount;

        axnv.safeTransfer(to, amount);

        emit AXNVReleased(to, amount, purpose);
    }

    function releaseAllAXNV(
        address to,
        string calldata purpose
    ) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid recipient");

        uint256 balance = axnv.balanceOf(address(this));
        require(balance > 0, "No AXNV");

        totalReleased += balance;

        axnv.safeTransfer(to, balance);

        emit AXNVReleased(to, balance, purpose);
    }

    function rescueERC20(
        address token,
        uint256 amount,
        address to
    ) external onlyOwner nonReentrant {
        require(token != address(axnv), "Use releaseAXNV");
        require(token != address(0), "Invalid token");
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");

        IERC20(token).safeTransfer(to, amount);

        emit ERC20Recovered(token, to, amount);
    }

    function contractAXNVBalance() public view returns (uint256) {
        return axnv.balanceOf(address(this));
    }

    function reserveInfo()
        external
        view
        returns (
            address axnvToken,
            uint256 funded,
            uint256 released,
            uint256 balance
        )
    {
        axnvToken = address(axnv);
        funded = totalFunded;
        released = totalReleased;
        balance = contractAXNVBalance();
    }
}
