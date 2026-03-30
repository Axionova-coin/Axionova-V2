// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/finance/VestingWallet.sol";

contract FounderVestingVault is VestingWallet {

    constructor(
        address beneficiary_,
        uint64 startTimestamp_,
        uint64 cliffDurationSeconds_,
        uint64 vestingDurationSeconds_
    )
        VestingWallet(
            beneficiary_,
            startTimestamp_ + cliffDurationSeconds_,
            vestingDurationSeconds_
        )
    {}

    /// @notice Marker so TeamAllocationHoldingVault can validate destination
    function isVestingContract() external pure returns (bool) {
        return true;
    }

    /// @notice Convenience wrapper to release AXNV tokens
    function releaseAXNV(address axnvToken) external {
        release(axnvToken);
    }
}
