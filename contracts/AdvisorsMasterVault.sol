// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AdvisorsMasterVault
 * @notice Holds AXNV allocation for Advisors & Partners.
 *         Tokens can only be transferred to approved advisor vesting contracts.
 *         No direct withdrawals to EOAs are allowed.
 */
contract AdvisorsMasterVault is Ownable {
    IERC20 public immutable axnv;

    /// @notice Approved vesting contracts
    mapping(address => bool) public isAdvisorVesting;

    event AdvisorVestingApproved(address indexed vesting);
    event AdvisorVestingRevoked(address indexed vesting);
    event TokensTransferred(address indexed vesting, uint256 amount);

    constructor(address _axnv, address _owner) {
        require(_axnv != address(0), "AXNV address zero");
        require(_owner != address(0), "Owner address zero");

        axnv = IERC20(_axnv);
        _transferOwnership(_owner);
    }

    /**
     * @notice Approve an advisor vesting contract
     * @dev Vesting contracts must be deployed separately
     */
    function approveAdvisorVesting(address vesting) external onlyOwner {
        require(vesting != address(0), "Vesting address zero");
        isAdvisorVesting[vesting] = true;
        emit AdvisorVestingApproved(vesting);
    }

    /**
     * @notice Revoke an advisor vesting contract
     */
    function revokeAdvisorVesting(address vesting) external onlyOwner {
        isAdvisorVesting[vesting] = false;
        emit AdvisorVestingRevoked(vesting);
    }

    /**
     * @notice Transfer AXNV to an approved advisor vesting contract
     * @dev Prevents transfers to EOAs or unapproved contracts
     */
    function fundAdvisorVesting(address vesting, uint256 amount) external onlyOwner {
        require(isAdvisorVesting[vesting], "Not approved vesting");
        require(amount > 0, "Amount zero");

        axnv.transfer(vesting, amount);
        emit TokensTransferred(vesting, amount);
    }
}
