# Staking System

## Overview

The Axionova Staking contract enables AXNV holders to lock their tokens and earn fixed APR rewards while supporting long-term ecosystem participation. The contract separates staking logic from the core token contract, following Axionova's modular smart contract architecture.

The staking system is funded from a dedicated staking rewards allocation and is designed to protect user principal while maintaining transparent reward accounting.

---

## Features

- Fixed APR reward model
- Multiple staking durations
- Dedicated reward pool
- Configurable minimum stake
- Early withdrawal with penalty
- Reward reservation system
- Owner-funded rewards
- Emergency pause
- Safe recovery of excess tokens
- Read-only analytics functions

---

## Supported Lock Periods

| Duration | Lock Period |
|----------|------------:|
| Level 1 | 30 Days |
| Level 2 | 90 Days |
| Level 3 | 180 Days |
| Level 4 | 365 Days |

---

## Reward Model

| Stake Duration | Principal Returned | Reward | Penalty |
|---------------|-------------------:|--------|---------|
| Before 30 Days | 90% | None | 10% |
| 30–179 Days | 100% | Fixed APR based on selected duration | None |
| 180–365 Days | 100% | Fixed APR based on selected duration | None |
| At Maturity | 100% | Reserved reward released | None |

> Rewards are calculated during staking and reserved immediately to ensure sufficient reward availability.

---

## Reward Calculation

```
Reward = Stake Amount × APR × Duration ÷ 365 ÷ 100
```

Example:

| Stake | Duration | APR | Reward |
|-------:|---------:|----:|--------:|
| 100,000 AXNV | 365 Days | 8% | 8,000 AXNV |

---

## Staking Flow

1. User connects a Web3 wallet.
2. User approves AXNV spending.
3. User selects staking amount and duration.
4. Contract validates reward availability.
5. Stake is created and rewards are reserved.
6. User withdraws after maturity or exits early using Emergency Withdraw.

---

## Reward Funding

The staking contract does not mint new tokens.

Rewards are funded separately from the dedicated staking allocation of:

**56,250,000 AXNV**

The owner may fund rewards over time as participation grows.

---

## Security Features

- Reward reservation before accepting stakes
- Configurable minimum stake
- Emergency pause mechanism
- Owner-only administration
- Protection against recovering user principal
- Recovery limited to excess/unreserved AXNV
- Rescue of non-AXNV tokens sent accidentally
- Read-only monitoring functions for frontend dashboards

---

## Administrative Functions

The contract owner can:

- Fund staking rewards
- Pause or resume staking
- Update minimum stake
- Modify emergency withdrawal penalty
- Recover excess AXNV
- Rescue unsupported ERC20 tokens

Administrative operations do not affect active user stakes or reserved rewards.

---

## Design Decisions

### Modular Architecture

The staking contract is deployed independently from the AXNV token to reduce complexity and improve maintainability.

### Reserved Reward Accounting

Rewards are reserved when a stake is created, preventing future users from consuming rewards already promised to existing stakers.

### Fixed APR

A fixed reward model provides predictable returns and simplifies on-chain reward calculations.

### Dedicated Reward Pool

Staking rewards are funded from a separate allocation, isolating staking from treasury, presale, governance, and ecosystem funds.

### Early Withdrawal Protection

Users may exit before maturity using Emergency Withdraw, but forfeit rewards and incur a configurable penalty to discourage short-term participation.

---

## Future Improvements

Potential future enhancements include:

- Multiple staking pools
- Flexible APR controlled by governance
- NFT staking multipliers
- Auto-compounding rewards
- Governance-controlled reward parameters
- Analytics dashboard integration

---

## Tech Stack

- Solidity
- Hardhat
- OpenZeppelin
- Ethers.js
- BNB Smart Chain
