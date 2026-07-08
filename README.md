# Axionova Solidity DeFi Contracts

> Production-grade Solidity smart contracts powering the Axionova ecosystem.

![Solidity](https://img.shields.io/badge/Solidity-0.8.x-363636?style=for-the-badge&logo=solidity)
![Hardhat](https://img.shields.io/badge/Hardhat-Development-yellow?style=for-the-badge)
![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-Secure-blue?style=for-the-badge)
![BNB Smart Chain](https://img.shields.io/badge/BNB%20Chain-Mainnet-F3BA2F?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

---

## Overview

This repository contains the complete collection of Solidity smart contracts developed for the **Axionova** ecosystem.

The project follows a modular architecture with independent contracts responsible for token issuance, treasury management, governance, staking, presale, vesting, liquidity, rewards, ecosystem fund and more.

The contracts are designed with security, scalability and transparency in mind while leveraging battle-tested OpenZeppelin libraries and best development practices.

---

# Features

- ERC-20 Token
- Fixed Supply Tokenomics
- Multi-phase Presale
- Treasury & Reserve Management
- Liquidity Pool Allocation
- Team & Advisor Vesting
- Founder Vesting
- Staking Rewards
- Community Incentives
- Airdrop Distribution
- Governance Treasury
- Bug Bounty Fund
- Charity Fund
- Ecosystem Development Pool
- Role-Based Access Control
- Multisig Compatible
- OpenZeppelin Security Standards

---

# Tech Stack

- Solidity ^0.8.x
- Hardhat
- OpenZeppelin Contracts
- Ethers.js
- BNB Smart Chain

---

# Repository Structure

```
contracts/
│
├── token/
├── presale/
├── staking/
├── treasury/
├── governance/
├── vesting/
├── airdrop/
├── ecosystem/
├── interfaces/
├── libraries/
└── mocks/

scripts/
test/
ignition/
```

---

# Token Information

| Item | Value |
|-------|--------|
| Token Name | Axionova |
| Symbol | AXNV |
| Blockchain | BNB Smart Chain |
| Standard | ERC-20 / BEP-20 Compatible |
| Total Supply | **750,000,000 AXNV** |
| Minting | ❌ Disabled |
| Burn Mechanism | None |
| Ownership | Controlled through secure contract architecture |

---

# Token Distribution

| Category | Sub Category | Percentage | Tokens |
|----------|--------------|----------:|-------:|
| **Sale Pool (Presale)** | Presale | 35.00% | 262,500,000 |
| **Team & Advisors Vesting Pool** | Team Allocation | 6.00% | 45,000,000 |
| | Advisors & Partners | 2.00% | 15,000,000 |
| | Founder Vault | 1.47% | 11,000,000 |
| **Liquidity & Market Operations** | Liquidity Pool | 7.00% | 52,500,000 |
| | Marketing / CEXs | 3.00% | 22,500,000 |
| **Emissions & Incentives Pool** | Game Incentives | 8.00% | 60,000,000 |
| | Staking Rewards | 7.50% | 56,250,000 |
| | Community Incentives | 2.00% | 15,000,000 |
| | Airdrop Campaigns | 0.53% | 4,000,000 |
| **Ecosystem & R&D Pool** | Ecosystem Development | 8.00% | 60,000,000 |
| | Reserve | 15.50% | 116,250,000 |
| **Treasury** | Governance | 2.00% | 15,000,000 |
| | Bug Bounty | 1.00% | 7,500,000 |
| | Charity / Social Impact | 1.00% | 7,500,000 |
| | **TOTAL** | **100.00%** | **750,000,000** |

---

# Smart Contract Modules

### Token

- AXNV ERC20 Token
- Fixed Supply
- Secure Ownership Controls

### Presale

- Multi-phase Token Sale
- USDT Payments
- Automatic Phase Progression
- Token Claim Mechanism

### Vesting

- Founder Vesting
- Team Vesting
- Advisor Vesting
- Linear Token Release

### Treasury

- Reserve Vault
- Governance Vault
- Marketing Allocation
- Charity Allocation
- Bug Bounty Fund

### Staking

- Reward Distribution
- Configurable Lock Periods
- APR-based Rewards

### Governance

- DAO Ready Architecture
- Governance Treasury
- Timelock Compatible

### Incentives

- Community Rewards
- Airdrops
- Game Incentives
- Ecosystem Development

---

# Security

Security has been a primary design objective throughout development.

Key principles include:

- OpenZeppelin Contracts
- Role-Based Access Control
- Immutable Token Supply
- Modular Contract Architecture
- Treasury Separation
- Gas Efficient Design
- Safe Transfer Patterns
- Extensive Internal Testing

---

# Development

Clone the repository

```bash
git clone https://github.com/<your-username>/axionova-solidity-defi-contracts.git
```

Install dependencies

```bash
npm install
```

Compile

```bash
npx hardhat compile
```

Run tests

```bash
npx hardhat test
```

Deploy

```bash
npx hardhat run scripts/deploy.js --network bsc
```

---

# Future Enhancements

- DAO Governance Expansion
- Cross-Chain Support
- Yield Strategies
- Advanced Staking Pools
- On-chain Treasury Analytics
- Additional Ecosystem Modules

---

# Disclaimer

These contracts are provided for educational and portfolio purposes. Production deployments should always undergo comprehensive security reviews and independent smart contract audits before handling real assets.

---

## Author

**Aditya Kumar K**

Blockchain Developer

Specializing in Solidity, Smart Contract Architecture, DeFi Protocols and Web3 Development.

---

## License

This project is licensed under the MIT License.
