// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AXNVBatchDistributor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable axnv;

    uint256 public totalDistributed;
    uint256 public batchCount;

    event BatchDistributed(
        uint256 indexed batchId,
        uint256 recipientCount,
        uint256 totalAmount,
        string purpose
    );

    event Distributed(
        uint256 indexed batchId,
        address indexed recipient,
        uint256 amount
    );

    event AXNVRecovered(address indexed to, uint256 amount);
    event ERC20Recovered(address indexed token, address indexed to, uint256 amount);

    constructor(address axnvToken, address initialOwner) Ownable(initialOwner) {
        require(axnvToken != address(0), "Invalid AXNV");
        require(initialOwner != address(0), "Invalid owner");

        axnv = IERC20(axnvToken);
    }

    function batchDistribute(
        address[] calldata recipients,
        uint256[] calldata amounts,
        string calldata purpose
    ) external onlyOwner nonReentrant returns (uint256 batchId) {
        uint256 length = recipients.length;

        require(length > 0, "Empty recipients");
        require(length == amounts.length, "Length mismatch");

        uint256 totalAmount;

        for (uint256 i = 0; i < length; i++) {
            require(recipients[i] != address(0), "Invalid recipient");
            require(amounts[i] > 0, "Zero amount");

            totalAmount += amounts[i];
        }

        require(totalAmount <= axnv.balanceOf(address(this)), "Insufficient AXNV");

        batchId = batchCount;
        batchCount += 1;

        totalDistributed += totalAmount;

        for (uint256 i = 0; i < length; i++) {
            axnv.safeTransfer(recipients[i], amounts[i]);

            emit Distributed(batchId, recipients[i], amounts[i]);
        }

        emit BatchDistributed(batchId, length, totalAmount, purpose);
    }

    function recoverAXNV(address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");
        require(amount <= axnv.balanceOf(address(this)), "Insufficient AXNV");

        axnv.safeTransfer(to, amount);

        emit AXNVRecovered(to, amount);
    }

    function rescueERC20(address token, address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(token != address(axnv), "Use recoverAXNV");
        require(token != address(0), "Invalid token");
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");

        IERC20(token).safeTransfer(to, amount);

        emit ERC20Recovered(token, to, amount);
    }

    function contractAXNVBalance() external view returns (uint256) {
        return axnv.balanceOf(address(this));
    }

    function distributorInfo()
        external
        view
        returns (
            address axnvToken,
            uint256 distributedTotal,
            uint256 batches,
            uint256 balance
        )
    {
        axnvToken = address(axnv);
        distributedTotal = totalDistributed;
        batches = batchCount;
        balance = axnv.balanceOf(address(this));
    }
}
