# Axionova Internal Smart Contract Audit

**Project:** Axionova V3 Smart Contracts

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
