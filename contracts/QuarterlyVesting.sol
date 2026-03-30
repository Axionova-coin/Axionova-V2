// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract QuarterlyVesting {

    address public beneficiary;
    IERC20 public token;

    uint256 public totalAmount;
    uint256 public claimedAmount;
    uint256 public start;

    uint256 public constant PERIOD = 90 days;
    uint256 public constant TOTAL_PERIODS = 5;

    bool public initialized;

    constructor() {
        initialized = true;
    }

    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "Not beneficiary");
        _;
    }

    function initialize(
        address _beneficiary,
        address _token,
        uint256 _totalAmount,
        uint256 _start
    ) external {
        require(!initialized, "Already initialized");

        beneficiary = _beneficiary;
        token = IERC20(_token);
        totalAmount = _totalAmount;
        start = _start;

        initialized = true;
    }

    function vestedAmount() public view returns (uint256) {
        if (block.timestamp < start) return 0;

        uint256 elapsed = block.timestamp - start;
        uint256 periodsPassed = elapsed / PERIOD;

        if (periodsPassed >= TOTAL_PERIODS) {
            return totalAmount;
        }

        return (totalAmount * periodsPassed) / TOTAL_PERIODS;
    }

    function claim() external onlyBeneficiary {
        uint256 vested = vestedAmount();
        uint256 claimable = vested - claimedAmount;

        require(claimable > 0, "Nothing to claim");

        claimedAmount += claimable;

        require(token.transfer(beneficiary, claimable), "Transfer failed");
    }
}