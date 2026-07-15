# Findings

---

## AXNV-001

**Severity**

Low

**Contract**

AXNVToken.sol

**Detector**

shadowing-local

**Description**

Parameter `owner` shadows `Ownable.owner()`.

**Impact**

None.

Code quality only.

**Exploitability**

None.

**Resolution**

Accepted Risk

Token already deployed.

No migration required.

**Status**

Closed

---
---

## AXNV-PS-001

**Contract**

AXNVPresaleVesting.sol

**Severity**

None

**Category**

Manual Review

**Description**

Purchase logic reviewed including multi-phase purchases, reserve accounting and oversubscription protection.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-PS-002

**Contract**

AXNVPresaleVesting.sol

**Severity**

None

**Category**

Manual Review

**Description**

Vesting and claim calculations reviewed.

The implementation correctly applies:

- 15% TGE unlock
- Linear vesting
- Double-claim prevention
- Final claim settlement

**Status**

Closed

---

## AXNV-PS-003

**Contract**

AXNVPresaleVesting.sol

**Severity**

Low

**Category**

Accepted Risk

**Description**

Slither reports timestamp-dependent logic.

The contract intentionally relies on `block.timestamp` for:

- Sale status
- TGE activation
- Vesting calculations

This behaviour is expected for a time-based vesting contract.

**Resolution**

Accepted.

No change required.

**Status**

Closed

---

## AXNV-PS-004

**Contract**

AXNVPresaleVesting.sol

**Severity**

Informational

**Category**

Optimization

**Description**

Slither reports `_advancePhase()` contains a state update inside a bounded loop.

The presale consists of only three phases, making the loop bounded and predictable.

**Resolution**

No change required.

**Status**

Closed

---
---

# AXNVTeamAdvisorFounderVestingVault Findings

## AXNV-TV-001

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed vesting implementation for Team, Advisors, and Founder
allocations.

**Result**

No exploitable issues identified.

**Status**

Closed

------------------------------------------------------------------------

## AXNV-TV-002

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed claim mechanism, batch claims, accounting, and double-claim
protection.

**Result**

No exploitable issues identified.

**Status**

Closed

------------------------------------------------------------------------

## AXNV-TV-003

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed reserve accounting and recoverable balance calculations.

Reserved allocations remain protected.

**Status**

Closed

------------------------------------------------------------------------

## AXNV-TV-004

**Severity:** Low

**Category:** Accepted Risk

**Description**

Slither reports timestamp-dependent vesting calculations.

Timestamp usage is intentional and required for cliff and linear
vesting.

**Resolution**

Accepted. No change required.

**Status**

Closed

------------------------------------------------------------------------

## AXNV-TV-005

**Severity:** Informational

**Category:** Optimization

**Description**

Minor optimization suggestions reported by Slither.

No impact on contract security or correctness.

**Resolution**

No change required.

**Status**

Closed

---
---

# AXNVStaking Findings

## AXNV-ST-001

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed staking creation, accounting, and reward allocation.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-ST-002

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed reward calculations, maturity handling, and unstake logic.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-ST-003

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed reward pool accounting and principal protection.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-ST-004

**Severity:** Low

**Category:** Accepted Risk

**Description**

Slither reports timestamp-dependent reward calculations.

Timestamp usage is intentional and required for lock periods and APR calculations.

**Resolution**

Accepted.

No change required.

**Status**

Closed

---

## AXNV-ST-005

**Severity:** Informational

**Category:** Optimization

**Description**

Minor optimization recommendations reported by Slither.

No impact on contract security or correctness.

**Resolution**

No change required.

**Status**

Closed

---
---

# AXNVTreasury Findings

## AXNV-TR-001

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed treasury custody, accounting and transfer logic.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-TR-002

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed administrative controls, emergency pause and treasury management.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-TR-003

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed access control and authorization model.

**Result**

No privilege escalation or unauthorized treasury access identified.

**Status**

Closed

---

## AXNV-TR-004

**Severity:** Low

**Category:** Accepted Risk

**Description**

Slither reports timestamp and/or informational findings where applicable.

No exploitable impact on treasury security was identified.

**Resolution**

Accepted.

No change required.

**Status**

Closed

---

## AXNV-TR-005

**Severity:** Informational

**Category:** Optimization

**Description**

Minor optimization recommendations reported by Slither.

No impact on contract security or correctness.

**Resolution**

No change required.

**Status**

Closed

---
---

# AXNVLiquidityAllocationVault Findings

## AXNV-LV-001

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed liquidity allocation custody, accounting and release mechanism.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-LV-002

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed administrative controls, emergency pause and liquidity management.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-LV-003

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed access control and authorization model.

**Result**

No privilege escalation or unauthorized liquidity access identified.

**Status**

Closed

---

## AXNV-LV-004

**Severity:** Low

**Category:** Accepted Risk

**Description**

Slither reports informational and timestamp-related observations where applicable.

No exploitable impact on liquidity security was identified.

**Resolution**

Accepted.

No change required.

**Status**

Closed

---

## AXNV-LV-005

**Severity:** Informational

**Category:** Optimization

**Description**

Minor optimization recommendations reported by Slither.

No impact on contract security or correctness.

**Resolution**

No change required.

**Status**

Closed

---
---

# AXNVCommunityIncentivesDistributor Findings

## AXNV-CI-001

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed community reward distribution, accounting and allocation logic.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-CI-002

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed claim mechanism, eligibility verification and double claim protection.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-CI-003

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed administrative controls, reward allocation and emergency controls.

**Result**

No unauthorized distribution paths identified.

**Status**

Closed

---

## AXNV-CI-004

**Severity:** Low

**Category:** Accepted Risk

**Description**

Slither reports timestamp and informational observations where applicable.

These are expected for scheduled distribution and claim operations.

**Resolution**

Accepted.

No change required.

**Status**

Closed

---

## AXNV-CI-005

**Severity:** Informational

**Category:** Optimization

**Description**

Minor optimization recommendations reported by Slither.

No impact on contract security or correctness.

**Resolution**

No change required.

**Status**

Closed

---
---

# AXNVAirdrop Findings

## AXNV-AD-001

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed Merkle proof verification, reward allocation and claim mechanism.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-AD-002

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed vesting implementation, unlock schedule and double claim protection.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-AD-003

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed administrative controls, Merkle root management and emergency controls.

**Result**

No unauthorized reward distribution paths identified.

**Status**

Closed

---

## AXNV-AD-004

**Severity:** Low

**Category:** Accepted Risk

**Description**

Slither reports timestamp-dependent and informational observations where applicable.

Timestamp usage is intentional for vesting and unlock calculations.

**Resolution**

Accepted.

No change required.

**Status**

Closed

---

## AXNV-AD-005

**Severity:** Informational

**Category:** Optimization

**Description**

Minor optimization recommendations reported by Slither.

No impact on contract security or correctness.

**Resolution**

No change required.

**Status**

Closed

---
---

# AXNVReserveVault Findings

## AXNV-RV-001

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed reserve custody, accounting and transfer mechanism.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-RV-002

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed administrative controls, reserve management and emergency controls.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-RV-003

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed access control and authorization model.

**Result**

No privilege escalation or unauthorized reserve access identified.

**Status**

Closed

---

## AXNV-RV-004

**Severity:** Low

**Category:** Accepted Risk

**Description**

Slither reports informational and timestamp-related observations where applicable.

No exploitable impact on reserve security was identified.

**Resolution**

Accepted.

No change required.

**Status**

Closed

---

## AXNV-RV-005

**Severity:** Informational

**Category:** Optimization

**Description**

Minor optimization recommendations reported by Slither.

No impact on contract security or correctness.

**Resolution**

No change required.

**Status**

Closed

---
---

# AXNVGovernanceVault Findings

## AXNV-GV-001

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed governance allocation custody, accounting and transfer mechanism.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-GV-002

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed administrative controls, governance fund management and emergency controls.

**Result**

No exploitable issues identified.

**Status**

Closed

---

## AXNV-GV-003

**Severity:** None

**Category:** Manual Review

**Description**

Reviewed access control and authorization model.

**Result**

No privilege escalation or unauthorized governance fund access identified.

**Status**

Closed

---

## AXNV-GV-004

**Severity:** Low

**Category:** Accepted Risk

**Description**

Slither reports informational and timestamp-related observations where applicable.

No exploitable impact on governance fund security was identified.

**Resolution**

Accepted.

No change required.

**Status**

Closed

---

## AXNV-GV-005

**Severity:** Informational

**Category:** Optimization

**Description**

Minor optimization recommendations reported by Slither.

No impact on contract security or correctness.

**Resolution**

No change required.

**Status**

Closed
