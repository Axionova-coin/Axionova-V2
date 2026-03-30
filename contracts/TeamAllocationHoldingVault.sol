// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IVestingContract {
    function isVestingContract() external pure returns (bool);
}

contract TeamAllocationHoldingVault is Ownable {
    IERC20 public immutable axnvToken;

    bool public funded;

    event VaultFunded(uint256 amount);
    event TokensAllocated(address indexed vestingContract, uint256 amount);

    constructor(address _axnvToken, address initialOwner) {
        require(_axnvToken != address(0), "AXNV token address zero");
        require(initialOwner != address(0), "Owner address zero");

        axnvToken = IERC20(_axnvToken);
        _transferOwnership(initialOwner);
    }

    /// @notice One-time funding function (pull-based)
    function fundVault(uint256 amount) external onlyOwner {
        require(!funded, "Vault already funded");
        require(amount > 0, "Amount zero");

        funded = true;

        bool success = axnvToken.transferFrom(msg.sender, address(this), amount);
        require(success, "AXNV transfer failed");

        emit VaultFunded(amount);
    }

    /// @notice Allocate tokens to a vesting contract (one-way only)
    function allocateToVesting(address vestingContract, uint256 amount) external onlyOwner {
        require(funded, "Vault not funded");
        require(amount > 0, "Amount zero");
        require(vestingContract != address(0), "Vesting address zero");

        // Enforce vesting-only destination
        require(
            IVestingContract(vestingContract).isVestingContract(),
            "Destination is not a vesting contract"
        );

        bool success = axnvToken.transfer(vestingContract, amount);
        require(success, "AXNV transfer failed");

        emit TokensAllocated(vestingContract, amount);
    }
}
