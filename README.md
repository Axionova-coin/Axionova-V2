# Axionova Contracts

Official smart contract repository for **Axionova (AXNV)**.

## Overview

Axionova is a fixed-supply ERC20 token with governance-ready functionality and modular external contracts for presale, vesting, airdrop, staking, gaming incentives, AI rewards, and treasury operations.

The AXNV token contract is intentionally simple, non-upgradeable, and excludes minting, tax, blacklist, bridge, wrapper, flash-mint, and upgradeable proxy functionality.

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

## Deployed Contracts

| Contract | Address | Network |
|---|---|---|
| AXNV Token | `0x0c9c7B3e3D7F95F6f52F805250AFa7D2E335AeFD` | BSC Mainnet |
| AXNV Presale Vesting | `0x1FC5C6C2FCF34fC96bd298d60F1d5C1B767fd33a` | BSC Mainnet |

---

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

## Presale Vesting Contract

The AXNV presale vesting contract allows users to buy AXNV allocation using USDT. AXNV is not transferred immediately to users; purchased allocations remain in the contract and users claim AXNV through vesting after TGE [1].

### Payment Token

| Token | Address | Network |
|---|---|---|
| USDT | `0x55d398326f99059fF775485246999027B3197955` | BSC Mainnet |

### Presale Allocation

Total presale allocation:

```text
262,500,000 AXNV
