# Smart Contracts

## Overview

The Axionova ecosystem is built using a modular smart contract architecture where each contract has a single responsibility. Instead of embedding all functionality into a single contract, Axionova separates token management, staking, governance, treasury, vesting, liquidity, community rewards, and reserve management into dedicated modules.

This design improves maintainability, simplifies auditing, reduces deployment complexity, minimizes the impact of potential vulnerabilities, and allows individual components to evolve independently while interacting through well-defined interfaces.

---

## Contract Architecture

| Contract | Purpose | Status |
|----------|---------|--------|
| AXNV Token | ERC20 Token | ✅ Live |
| Presale Vesting | Token Sale & Vesting | ✅ Live |
| Airdrop | Merkle-Based Distribution | ✅ Live |
| Treasury | Treasury Management | ✅ Live |
| Staking | Reward Distribution | ✅ Live |
| Governor | DAO Governance | ✅ Live |
| Timelock | Governance Execution Delay | ✅ Live |
| Governance Vault | Governance Fund Management | ✅ Live |
| Liquidity Allocation Vault | Liquidity Allocation | ✅ Live |
| Reserve Vault | Reserve & Future Allocations | ✅ Live |
| Community Incentives Distributor | Campaign Rewards | ✅ Live |
| Team Advisor Founder Vesting Vault | Team & Founder Vesting | ✅ Live |

---

## Why Modular?

Axionova follows a modular architecture where each contract is responsible for a single functional area.

This approach provides several advantages:

- Reduces contract complexity and deployment risk.
- Limits the impact of bugs to individual modules instead of the entire ecosystem.
- Makes contracts easier to audit and maintain.
- Allows independent upgrades or replacement of ecosystem modules without modifying the AXNV token contract.
- Improves readability and long-term maintainability.
- Separates business logic from token logic.
- Enables future expansion without increasing the size or complexity of the core token contract.

The AXNV token itself remains intentionally lightweight while ecosystem functionality is implemented through specialized contracts.

---

## Contract Dependencies

The ecosystem contracts interact through the AXNV token while maintaining clear separation of responsibilities.

| Contract | Depends On |
|----------|------------|
| AXNV Token | OpenZeppelin ERC20, ERC20Permit, ERC20Votes |
| Presale Vesting | AXNV Token, USDT |
| Airdrop | AXNV Token |
| Staking | AXNV Token |
| Treasury | AXNV Token |
| Liquidity Allocation Vault | AXNV Token |
| Reserve Vault | AXNV Token |
| Community Incentives Distributor | AXNV Token |
| Team Advisor Founder Vesting Vault | AXNV Token |
| Governor | AXNV Token (ERC20Votes), Timelock |
| Timelock | Governor |
| Governance Vault | AXNV Token |

The AXNV token acts as the central asset while each supporting contract manages a dedicated ecosystem function.

---

## Upgrade Strategy

The AXNV token is designed as a fixed-supply, non-upgradeable ERC20 token.

Core token properties such as supply, voting capability, and transfer logic remain immutable after deployment.

Operational parameters within ecosystem contracts are managed through ownership or governance where appropriate, including:

- Treasury distributions
- Community incentive campaigns
- Reward funding
- Staking configuration
- Governance proposals
- Vesting schedules

This approach preserves trust in the core asset while allowing operational flexibility across the ecosystem.

---

## Deployment Process

The contracts were deployed in a staged sequence to satisfy dependency requirements.

1. Deploy AXNV Token
2. Deploy Treasury
3. Deploy Team Advisor Founder Vesting Vault
4. Deploy Presale Vesting
5. Deploy Airdrop
6. Deploy Staking
7. Deploy Liquidity Allocation Vault
8. Deploy Reserve Vault
9. Deploy Community Incentives Distributor
10. Deploy Timelock
11. Deploy Governor
12. Deploy Governance Vault
13. Verify all contracts on BscScan
14. Configure ownership, permissions, allocations, and contract relationships
15. Integrate contracts with the Web3 frontend

---

## Design Decisions

### 1. Fixed Supply

The total supply is permanently capped at **750,000,000 AXNV**, eliminating inflation risk and preventing future minting.

### 2. Separation of Concerns

Each contract is responsible for one subsystem, making the architecture easier to understand, test, audit, and maintain.

### 3. Governance Ready

The AXNV token implements **ERC20Votes**, allowing governance functionality without modifying the token contract.

### 4. Dedicated Allocation Contracts

Treasury, liquidity, reserve, governance, staking, and vesting allocations are isolated into dedicated contracts instead of being managed directly by the token.

### 5. Transparent On-Chain Accounting

Each module maintains its own allocation limits, events, and accounting logic, improving transparency and simplifying ecosystem monitoring.

### 6. Security-First Design

Administrative operations are restricted through ownership, emergency pause mechanisms are available where appropriate, and user funds remain isolated from unrelated ecosystem components.

### 7. Standards-Based Development

The ecosystem is built using audited OpenZeppelin libraries and established Solidity development practices to maximize compatibility and reduce implementation risk.

### 8. Production Deployment

All contracts are deployed on **BNB Smart Chain Mainnet**, source-verified on BscScan, and integrated with the Axionova Web3 frontend for production use.
