# Axionova (AXNV) Smart Contracts

Official smart contract repository for **Axionova (AXNV)**.

## Overview

Axionova is a fixed-supply ERC20 token deployed on BNB Smart Chain with burn, permit, and governance-ready voting support.

The token contract is designed to remain simple and modular. Presale, vesting, airdrop, staking, gaming incentives, AI rewards, treasury, and governance systems are handled through separate contracts.

## Network

| Item | Value |
|---|---|
| Network | BNB Smart Chain Mainnet |
| Chain ID | 56 |
| Hardhat Network Name | `bsc` |

## Deployed Contracts

| Contract | Address |
|---|---|
| AXNV Token | `0x0c9c7B3e3D7F95F6f52F805250AFa7D2E335AeFD` |
| AXNV Presale Vesting | `0x1FC5C6C2FCF34fC96bd298d60F1d5C1B767fd33a` |

## Deployer

| Role | Address |
|---|---|
| Deployer | `0x688b88064B7C500f9Ce817d6EADA2665784D2FB6` |

## Token Details

| Item | Value |
|---|---|
| Name | Axionova |
| Symbol | AXNV |
| Decimals | 18 |
| Total Supply | 750,000,000 AXNV |
| Standard | ERC20 |
| Burnable | Yes |
| Permit | Yes |
| Votes / Governance Ready | Yes |
| Mintable | No |
| Upgradeable | No |
| Tax / Fee | No |
| Blacklist | No |
| Bridge Logic | No |
| Flash Mint | No |
| Wrapper | No |

## Token Features

The AXNV token includes:

- ERC20 standard functionality
- ERC20Burnable
- ERC20Permit
- ERC20Votes
- Ownable
- Fixed supply minted once at deployment
- No public or owner mint function
- No transfer tax
- No blacklist
- No upgradeable proxy

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

## Presale Vesting Contract

The AXNV presale vesting contract allows users to buy AXNV allocations using USDT.

Purchased AXNV is not transferred immediately. Tokens remain inside the presale vesting contract and become claimable according to the vesting schedule after TGE.

## Payment Token

| Token | Address | Network |
|---|---|---|
| USDT | `0x55d398326f99059fF775485246999027B3197955` | BNB Smart Chain Mainnet |

## Presale Allocation

Total presale allocation:

```text
262,500,000 AXNV
```

## Presale Phases

| Phase | Price | Allocation |
|---|---:|---:|
| Phase 1 | 0.005 USDT | 87,500,000 AXNV |
| Phase 2 | 0.0075 USDT | 87,500,000 AXNV |
| Phase 3 | 0.01 USDT | 87,500,000 AXNV |
| **Total** |  | **262,500,000 AXNV** |

## Presale Rules

- USDT only
- No minimum purchase
- No maximum purchase
- Phase prices are hardcoded
- Phase supplies are hardcoded
- Phase switching is automatic
- Manual phase change is not required
- Emergency pause is supported
- No refund system
- No soft cap
- Unsold AXNV can be withdrawn by owner
- Purchased AXNV remains in the contract until vested and claimed

## Presale Vesting Schedule

```text
15% unlocked at TGE
85% unlocked linearly over 12 months
```

Users can claim AXNV anytime after TGE as tokens become vested.

## Planned Modular Contracts

The AXNV token does not contain presale, airdrop, staking, gaming, AI, or treasury logic directly.

These systems are designed as separate modules:

- `AXNVPresaleVesting`
- `AxionovaAirdrop`
- `AxionovaVesting`
- `AxionovaTreasury`
- `AxionovaStaking`
- `AxionovaGamingRewards`
- `AxionovaAIRewards`
- `AxionovaGovernor`
- `AxionovaTimelock`

## Security Design

AXNV follows a minimal and modular architecture:

- Fixed supply minted once
- No minting after deployment
- No transfer tax
- No blacklist
- No upgradeable proxy for the token
- No bridge logic inside the token
- No presale or airdrop logic inside the token
- Governance compatibility through ERC20Votes
- Presale purchases recorded in a separate vesting contract
- Presale tokens claimable only after TGE and vesting unlocks

## License

MIT
