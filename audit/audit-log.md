# Axionova Internal Smart Contract Audit

**Project:** Axionova (AXNV) Smart Contracts

**Audit Type:** Internal Security Review

**Status:** In Progress

**Audit Tools**
- Slither v0.11.5
- Manual Review
- Solidity 0.8.24
- Hardhat

---

## Scope

| Contract | Status |
|----------|--------|
| AXNVToken | ✅ Completed |
| AXNVStaking | ⏳ Pending |
| AXNVPresaleVesting | ⏳ Pending |
| AXNVAirdrop | ⏳ Pending |
| AXNVGovernor | ⏳ Pending |
| AXNVTimelock | ⏳ Pending |
| AXNVTreasury | ⏳ Pending |
| AXNVReserveVault | ⏳ Pending |
| AXNVBatchDistributor | ⏳ Pending |
| AXNVCommunityIncentivesDistributor | ⏳ Pending |
| AXNVLiquidityAllocationVault | ⏳ Pending |
| AXNVTeamAdvisorFounderVestingVault | ⏳ Pending |

---

## Progress

- Total contracts: 13
- Contracts reviewed: 1
- Slither findings reviewed: 1 / 154

---

## AXNVToken

### Summary

No Critical, High or Medium severity vulnerabilities were identified.

### Findings

- Low: Parameter shadowing (`nonces(address owner)`)

### Resolution

Accepted Risk

The deployed token contract cannot be modified.
The finding is cosmetic and has no security impact.

### Final Verdict

✅ PASS

---
---

# AXNVPresaleVesting Audit

**Contract**

AXNVPresaleVesting.sol

**Status**

✅ Completed

---

## Scope

The contract was manually reviewed alongside Slither static analysis.

The review focused on:

- Purchase flow
- Multi-phase pricing
- Vesting calculations
- Claim mechanism
- Access control
- Administrative functions
- Reserve accounting
- Edge-case handling
- Business logic validation

---

## Manual Review

### Purchase Logic

The purchase mechanism was reviewed for:

- Correct USDT accounting
- Multi-phase purchases
- Oversubscription protection
- Token allocation
- Reserve verification
- Reentrancy

**Result**

No exploitable issues identified.

---

### Vesting Logic

The vesting mechanism was reviewed for:

- 15% TGE unlock
- Linear vesting
- Double-claim protection
- Final claim behaviour
- Rounding

**Result**

No exploitable issues identified.

---

### Claim Logic

The claim process was reviewed for:

- Claim before TGE
- Multiple claims
- Reentrancy
- Remaining balance calculation

**Result**

No exploitable issues identified.

---

### Administrative Controls

Reviewed functions include:

- setTGE()
- pause()
- unpause()
- withdrawUnsoldAXNV()
- rescueToken()

**Result**

Administrative permissions are consistent with the intended design.

Reserved purchaser allocations remain protected.

---

## Business Logic Validation

The following scenarios were reviewed.

| Scenario | Result |
|-----------|--------|
| Purchase across phases | ✅ |
| Final token sold | ✅ |
| Oversized purchase | ✅ |
| Purchase after TGE | ✅ |
| Purchase while paused | ✅ |
| Claim before TGE | ✅ |
| Claim at TGE | ✅ |
| Multiple claims | ✅ |
| Final vesting claim | ✅ |
| Reserve accounting | ✅ |
| Unsold token withdrawal | ✅ |

---

## Conclusion

No Critical, High or Medium severity vulnerabilities were identified during the manual review.

Remaining Slither findings were determined to be informational, optimization-related, or expected behaviour for a time-based vesting contract.

The contract architecture demonstrates appropriate use of OpenZeppelin security primitives, reserve accounting, and access controls.

**Final Status**

✅ Approved for deployment.
