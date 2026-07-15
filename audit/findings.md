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

## AXNV-002

Reserved

---

## AXNV-003

Reserved

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
