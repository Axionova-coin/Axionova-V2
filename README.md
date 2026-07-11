# Axionova Token

Official smart contract repository for **Axionova (AXNV)**.

## Overview

Axionova is designed as a fixed-supply ERC20 token with governance-ready functionality and modular external contracts for presale, airdrop, vesting, staking, gaming incentives, and AI rewards.

The core token contract is intentionally simple, non-upgradeable, and excludes tax, blacklist, minting, bridge, wrapper, and flash-mint functionality.

---

## AXNV Token

| Item | Value |
|---|---|
| Token Name | Axionova |
| Token Symbol | AXNV |
| Total Supply | 750,000,000 AXNV |
| Decimals | 18 |
| Token Type | ERC20 |
| Mintable | No |
| Burnable | Yes |
| Permit | Yes |
| Votes / Governance Ready | Yes |
| Upgradeable | No |
| Tax / Fee | No |
| Blacklist | No |
| Bridge | No |

---

## Deployed Contract

| Contract | Address |
|---|---|
| AXNVToken | `0x0c9c7B3e3D7F95F6f52F805250AFa7D2E335AeFD` |

## Deployer

| Role | Address |
|---|---|
| Deployer | `0x688b88064B7C500f9Ce817d6EADA2665784D2FB6` |

---

## Core Token Features

The AXNV token includes:

- ERC20 standard functionality
- ERC20Burnable
- ERC20Permit
- ERC20Votes
- Ownable
- Fixed supply minted once at deployment
- No public or owner mint function

---

## Tokenomics

Total supply: **750,000,000 AXNV**

| Category | Allocation |
|---|---:|
| Presale | 262,500,000 |
| Team Allocation | 37,500,000 |
| Advisors & Partners | 11,250,000 |
| Founder Vault | 9,350,000 |
| Liquidity Pool | 52,500,000 |
| Game Incentives | 60,000,000 |
| AI Rewards | 37,500,000 |
| Staking Rewards | 56,250,000 |
| Community Incentives | 11,250,000 |
| Airdrop Campaigns | 4,000,000 |
| Reserve | 116,250,000 |
| Governance | 11,250,000 |
| Ecosystem Development | 42,900,000 |
| Marketing / CEXs | 22,500,000 |
| Bug Bounty | 7,500,000 |
| Charity / Social Impact | 7,500,000 |

---

## Planned Modular Contracts

The AXNV token does not contain presale, airdrop, staking, gaming, AI, or treasury logic directly.

These systems are planned as separate contracts:

- `AxionovaPresaleV3`
- `AxionovaAirdropV3`
- `AxionovaVestingV3`
- `AxionovaTreasuryV3`
- `AxionovaStakingV3`
- `AxionovaGamingRewardsV3`
- `AxionovaAIRewardsV3`
- `AxionovaGovernorV3`
- `AxionovaTimelockV3`

---

## Development Setup

Install dependencies:

```bash
npm install
