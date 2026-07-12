# Axionova (AXNV) Smart Contracts

Official smart contract repository for **Axionova (AXNV)**.

## Overview

Axionova is a fixed-supply ERC20 token deployed on BNB Smart Chain with burn, permit, and governance-ready voting support.

The AXNV token contract is designed to remain simple and modular. Presale, vesting, airdrop, staking, gaming incentives, AI rewards, liquidity, treasury, and governance systems are handled through separate contracts.

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
| AXNV Airdrop | `0xA1680767D1F1bD2d117d1F53EAFd6C6F78096F98` |
| AXNV Team Advisor Founder Vesting Vault | `0xFb039a997F34794CdCb80Df1ac86154C99aeAdfb` |
| AXNV Treasury | `0xe1f3377Afe75Eb9051e300488C174373DEe16B69` |
| AXNV Staking | `0x9f27A15A862323449dfe14988E13aE93F5b4cD13` |
| AXNV Liquidity Allocation Vault | `0x801822D37a4A56D93a2D7E0A412b7E0a72f34e77` |
| AXNV Timelock | `0x3bc9461e1f69a6Be7180A7630A62b69edF73CC68` |
| AXNV Governor | `0x9558c7B64e8Aa857104bf2b6BE3e5C2cE8f9B5C5` |
| AXNV Governance Vault | `0xE330F50b928105271c3ab4272EdEe753F505b423` |

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
- The contract requires sufficient AXNV balance before accepting purchases [1]

## Presale Vesting Schedule

```text
15% unlocked at TGE
85% unlocked linearly over 12 months
```

Users can claim AXNV anytime after TGE as tokens become vested.

## Airdrop Contract

The AXNV airdrop contract is a Merkle-based multi-round airdrop system.

Each eligible wallet receives a fixed **200 AXNV** allocation per airdrop claim.

## Airdrop Allocation

Total airdrop allocation:

```text
4,000,000 AXNV
```

## Airdrop Rules

- Merkle proof based
- Multi-round support
- Each eligible wallet receives 200 AXNV
- A wallet can receive the airdrop only once
- Previous recipients can be marked to prevent duplicate claims
- Round activation/deactivation is supported
- Emergency pause is supported
- Unclaimed rewards do not expire
- Reserved AXNV cannot be recovered by owner
- Merkle leaf format: `keccak256(abi.encode(roundId, wallet))` [2]

## Airdrop Vesting Schedule

```text
50% unlocked at TGE
50% unlocked linearly over 90 days
```

Users can claim AXNV anytime after TGE as tokens become vested.

## Team Advisor Founder Vesting Vault

The AXNV Team Advisor Founder Vesting Vault manages locked AXNV allocations for team members, advisors, partners, and the founder allocation in a single category-based vesting contract.

## Vesting Vault Allocation

Total vault allocation:

```text
58,100,000 AXNV
```

| Category | Allocation |
|---|---:|
| Team Allocation | 37,500,000 AXNV |
| Advisors & Partners | 11,250,000 AXNV |
| Founder Vault | 9,350,000 AXNV |
| **Total** | **58,100,000 AXNV** |

## Vesting Vault Schedule

| Category | Cliff | Linear Vesting |
|---|---:|---:|
| Team Allocation | 12 months | 24 months |
| Advisors & Partners | 6 months | 24 months |
| Founder Vault | 12 months | 48 months |

## Vesting Vault Rules

- Category-wise allocation caps
- Separate vesting periods by category
- Claims can be paused by owner
- Beneficiaries can claim vested AXNV after unlock
- Batch schedule creation is supported
- Batch claiming is supported
- Unallocated AXNV can be recovered by owner
- Reserved/allocated AXNV remains protected for beneficiaries

## Treasury Contract

The AXNV Treasury contract manages treasury allocations using category-wise caps.

## Treasury Allocation

Total treasury allocation:

```text
80,400,000 AXNV
```

| Category | Allocation |
|---|---:|
| Ecosystem Development | 42,900,000 AXNV |
| Marketing / CEXs | 22,500,000 AXNV |
| Bug Bounty | 7,500,000 AXNV |
| Charity / Social Impact | 7,500,000 AXNV |
| **Total** | **80,400,000 AXNV** |

## Treasury Category IDs

| Category ID | Category |
|---:|---|
| 1 | Ecosystem Development |
| 2 | Marketing / CEXs |
| 3 | Bug Bounty |
| 4 | Charity / Social Impact |

## Treasury Rules

- Category-wise spending caps
- Total treasury spending cap
- Owner-controlled spending
- Batch spending support
- Emergency pause support
- Excess AXNV recovery support
- Non-AXNV ERC20 rescue support
- Treasury spend events include category, recipient, amount, and purpose

## Staking Contract

The AXNV staking contract allows holders to stake AXNV and earn rewards based on stake duration.

## Staking Allocation

Total staking rewards allocation:

```text
56,250,000 AXNV
```

## Staking Rules

- Minimum stake: 10,000 AXNV
- Rewards are funded into the staking contract
- Staking rewards are capped by the staking rewards allocation
- Users can withdraw before 1 month with a 10% penalty and no reward
- Users can withdraw after 1 month and before 6 months with no penalty and no reward
- Users can claim rewards after 6 months
- Rewards accrue at 5% APR for the first 6 months
- Rewards accrue at 8% APR after 6 months
- Penalty AXNV remains inside the staking contract
- Unallocated AXNV can be withdrawn by owner in emergency
- Non-AXNV ERC20 rescue is supported

## Staking Reward Model

| Stake Duration | Principal | Reward | Penalty |
|---|---:|---:|---:|
| Before 1 month | 90% returned | No reward | 10% |
| 1 month to before 6 months | 100% returned | No reward | No penalty |
| After 6 months | 100% returned | 5% APR for first 6 months + 8% APR after 6 months | No penalty |

## Liquidity Allocation Vault

The AXNV Liquidity Allocation Vault holds the liquidity pool allocation until liquidity deployment is required.

The vault does not create liquidity by itself. It stores the liquidity allocation and releases AXNV to the configured liquidity manager when release is enabled.

## Liquidity Allocation

Total liquidity allocation:

```text
52,500,000 AXNV
```

## Liquidity Vault Rules

- Liquidity allocation cap: 52,500,000 AXNV
- AXNV can be funded into the vault by owner
- Release is paused by default
- AXNV can only be released to the configured liquidity manager
- Released AXNV is tracked by the vault
- Excess AXNV can be recovered by owner
- Non-AXNV ERC20 rescue is supported
- Intended for liquidity deployment after presale completion

## Governance System

The AXNV governance system uses a timelock-based DAO structure where AXNV holders can create and vote on proposals, and approved actions execute after a timelock delay.

## Governance Contracts

| Contract | Purpose |
|---|---|
| AXNVTimelock | Delays execution of governance-approved actions |
| AXNVGovernor | Handles proposals, voting, quorum, and execution |
| AXNVGovernanceVault | Holds the governance allocation of 11,250,000 AXNV |

## Governance Settings

| Setting | Value |
|---|---:|
| Voting delay | 1 day (~28,800 blocks) |
| Voting period | 5 days (~144,000 blocks) |
| Proposal threshold | 500,000 AXNV |
| Quorum | 2% of total supply |
| Timelock delay | 2 days |

## Governance Vault Allocation

Total governance vault allocation:

```text
11,250,000 AXNV
```

## Governance Vault Rules

- Governance allocation cap: 11,250,000 AXNV
- AXNV can be funded into the vault by owner
- Release can be paused by owner
- Governance AXNV can be released with a specified purpose
- Excess AXNV can be recovered by owner
- Non-AXNV ERC20 rescue is supported

## Governance Flow

```text
AXNV holders delegate votes
↓
Proposal created (requires 500,000 AXNV voting power)
↓
1 day voting delay
↓
5 day voting period
↓
Proposal passes if quorum (2%) and majority met
↓
Proposal queued in Timelock
↓
2 day timelock delay
↓
Proposal executed
```

## Planned Modular Contracts

The AXNV token does not contain presale, airdrop, staking, gaming, AI, liquidity, treasury, or governance logic directly.

These systems are designed as separate modules:

- `AXNVPresaleVesting`
- `AXNVAirdrop`
- `AXNVTeamAdvisorFounderVestingVault`
- `AXNVTreasury`
- `AXNVStaking`
- `AXNVLiquidityAllocationVault`
- `AXNVTimelock`
- `AXNVGovernor`
- `AXNVGovernanceVault`
- `AxionovaGamingRewards`
- `AxionovaAIRewards`

## Security Design

AXNV follows a minimal and modular architecture:

- Fixed supply minted once
- No minting after deployment
- No transfer tax
- No blacklist
- No upgradeable proxy for the token
- No bridge logic inside the token
- No presale, airdrop, vesting, staking, liquidity, treasury, or governance logic inside the token
- Governance compatibility through ERC20Votes
- Presale purchases recorded in a separate vesting contract
- Presale tokens claimable only after TGE and vesting unlocks
- Airdrop claims verified using Merkle proofs
- Airdrop tokens claimable only after TGE and vesting unlocks
- Team, advisor, and founder allocations managed through a dedicated vesting vault
- Treasury allocations managed through a dedicated category-capped treasury contract
- Staking rewards managed through a dedicated staking contract
- Liquidity allocation managed through a dedicated liquidity vault
- Governance actions protected by a timelock delay

## License

MIT
