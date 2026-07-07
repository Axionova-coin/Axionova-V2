// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title V2Airdrop
 * @notice Multi-round Merkle airdrop contract for AXNV V2.
 *
 * Each eligible wallet receives 200 AXNV per round.
 *
 * Vesting:
 * - 50% unlocks immediately at TGE.
 * - Remaining 50% vests linearly over 90 days after TGE.
 * - Users can claim anytime after TGE.
 * - Unclaimed rewards never expire.
 *
 * Merkle leaf format:
 * keccak256(abi.encode(roundId, wallet))
 */
contract V2Airdrop is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    uint256 public constant REWARD_PER_WALLET = 200 ether;
    uint256 public constant INITIAL_UNLOCK_BPS = 5_000;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant VESTING_DURATION = 90 days;

    // =============================================================
    //                           IMMUTABLES
    // =============================================================

    IERC20 public immutable axnv;

    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct Round {
        bytes32 merkleRoot;
        uint64 roundStartTime;
        uint64 eligibleWallets;
        bool active;
    }

    // =============================================================
    //                            STORAGE
    // =============================================================

    uint64 public tgeTimestamp;

    uint256 public nextRoundId;

    uint256 public totalReservedUnclaimed;

    mapping(uint256 => Round) public rounds;

    mapping(uint256 => mapping(address => uint256)) public claimed;

    mapping(uint256 => uint256) public totalClaimedByRound;

    // =============================================================
    //                             ERRORS
    // =============================================================

    error ZeroAddress();
    error InvalidMerkleRoot();
    error InvalidTGETime();
    error TGEAlreadyStarted();
    error TGENotSet();
    error TGENotStarted();
    error RoundDoesNotExist();
    error RoundNotActive();
    error RoundNotStarted();
    error InvalidProof();
    error NothingToClaim();
    error InvalidRecipient();
    error InvalidWalletCount();
    error InsufficientAXNVBalance();
    error CannotRecoverReservedAXNV();
    error InvalidUpdate();

    // =============================================================
    //                             EVENTS
    // =============================================================

    event TGETimeUpdated(uint64 indexed newTgeTimestamp);

    event RoundCreated(
        uint256 indexed roundId,
        bytes32 indexed merkleRoot,
        uint64 roundStartTime,
        uint64 eligibleWallets,
        bool active
    );

    event RoundUpdated(
        uint256 indexed roundId,
        bytes32 indexed merkleRoot,
        uint64 roundStartTime,
        uint64 eligibleWallets,
        bool active
    );

    event Claimed(
        uint256 indexed roundId,
        address indexed user,
        uint256 amount,
        uint256 totalClaimed
    );

    event TokensRecovered(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(address axnvToken, address initialOwner) Ownable(initialOwner) {
        if (axnvToken == address(0)) revert ZeroAddress();
        if (initialOwner == address(0)) revert ZeroAddress();

        axnv = IERC20(axnvToken);
    }

    // =============================================================
    //                         OWNER FUNCTIONS
    // =============================================================

    /**
     * @notice Sets or updates the TGE timestamp.
     * @dev Owner can update this only before TGE starts.
     */
    function setTGETime(uint64 newTgeTimestamp) external onlyOwner {
        if (tgeTimestamp != 0 && block.timestamp >= tgeTimestamp) {
            revert TGEAlreadyStarted();
        }

        if (newTgeTimestamp <= block.timestamp) {
            revert InvalidTGETime();
        }

        tgeTimestamp = newTgeTimestamp;

        emit TGETimeUpdated(newTgeTimestamp);
    }

    /**
     * @notice Creates a new airdrop round.
     * @param merkleRoot Merkle root for eligible wallets.
     * @param roundStartTime Informational/campaign start time. Claims require this time and TGE to have started.
     * @param eligibleWallets Number of eligible wallets in this round.
     * @param active Whether the round should be active immediately.
     */
    function createRound(
        bytes32 merkleRoot,
        uint64 roundStartTime,
        uint64 eligibleWallets,
        bool active
    ) external onlyOwner returns (uint256 roundId) {
        if (merkleRoot == bytes32(0)) revert InvalidMerkleRoot();
        if (eligibleWallets == 0) revert InvalidWalletCount();

        roundId = nextRoundId;
        nextRoundId++;

        rounds[roundId] = Round({
            merkleRoot: merkleRoot,
            roundStartTime: roundStartTime,
            eligibleWallets: eligibleWallets,
            active: active
        });

        uint256 addedReserve = uint256(eligibleWallets) * REWARD_PER_WALLET;
        totalReservedUnclaimed += addedReserve;

        if (active) {
            _checkAXNVBalance();
        }

        emit RoundCreated(
            roundId,
            merkleRoot,
            roundStartTime,
            eligibleWallets,
            active
        );
    }

    /**
     * @notice Updates an existing round.
     * @dev Can update Merkle root, start time, eligible wallet count, and active status.
     */
    function updateRound(
        uint256 roundId,
        bytes32 merkleRoot,
        uint64 roundStartTime,
        uint64 eligibleWallets,
        bool active
    ) external onlyOwner {
        if (!_roundExists(roundId)) revert RoundDoesNotExist();
        if (merkleRoot == bytes32(0)) revert InvalidMerkleRoot();
        if (eligibleWallets == 0) revert InvalidWalletCount();

        Round storage round = rounds[roundId];

        uint256 oldTotalAllocation = uint256(round.eligibleWallets) * REWARD_PER_WALLET;
        uint256 newTotalAllocation = uint256(eligibleWallets) * REWARD_PER_WALLET;
        uint256 alreadyClaimed = totalClaimedByRound[roundId];

        if (newTotalAllocation < alreadyClaimed) revert InvalidUpdate();

        uint256 oldUnclaimedReserve = oldTotalAllocation - alreadyClaimed;
        uint256 newUnclaimedReserve = newTotalAllocation - alreadyClaimed;

        if (newUnclaimedReserve > oldUnclaimedReserve) {
            totalReservedUnclaimed += newUnclaimedReserve - oldUnclaimedReserve;
        } else if (oldUnclaimedReserve > newUnclaimedReserve) {
            totalReservedUnclaimed -= oldUnclaimedReserve - newUnclaimedReserve;
        }

        round.merkleRoot = merkleRoot;
        round.roundStartTime = roundStartTime;
        round.eligibleWallets = eligibleWallets;
        round.active = active;

        if (active) {
            _checkAXNVBalance();
        }

        emit RoundUpdated(
            roundId,
            merkleRoot,
            roundStartTime,
            eligibleWallets,
            active
        );
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Recovers tokens from the contract.
     * @dev For AXNV, owner can recover only unallocated/unreserved AXNV.
     */
    function recoverToken(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (to == address(0)) revert InvalidRecipient();

        if (token == address(axnv)) {
            uint256 balance = axnv.balanceOf(address(this));
            uint256 recoverable = balance > totalReservedUnclaimed
                ? balance - totalReservedUnclaimed
                : 0;

            if (amount > recoverable) revert CannotRecoverReservedAXNV();
        }

        IERC20(token).safeTransfer(to, amount);

        emit TokensRecovered(token, to, amount);
    }

    // =============================================================
    //                          USER FUNCTIONS
    // =============================================================

    /**
     * @notice Claims currently unlocked AXNV for a round.
     */
    function claim(
        uint256 roundId,
        bytes32[] calldata proof
    ) external nonReentrant whenNotPaused {
        Round memory round = _getValidRound(roundId);

        if (tgeTimestamp == 0) revert TGENotSet();
        if (block.timestamp < tgeTimestamp) revert TGENotStarted();
        if (block.timestamp < round.roundStartTime) revert RoundNotStarted();

        if (!_verify(roundId, msg.sender, proof, round.merkleRoot)) {
            revert InvalidProof();
        }

        uint256 amount = claimable(roundId, msg.sender);

        if (amount == 0) revert NothingToClaim();

        claimed[roundId][msg.sender] += amount;
        totalClaimedByRound[roundId] += amount;
        totalReservedUnclaimed -= amount;

        axnv.safeTransfer(msg.sender, amount);

        emit Claimed(
            roundId,
            msg.sender,
            amount,
            claimed[roundId][msg.sender]
        );
    }

    // =============================================================
    //                          VIEW FUNCTIONS
    // =============================================================

    function claimable(
        uint256 roundId,
        address user
    ) public view returns (uint256) {
        uint256 unlocked = unlockedAmount(roundId, user);
        uint256 alreadyClaimed = claimed[roundId][user];

        if (unlocked <= alreadyClaimed) {
            return 0;
        }

        return unlocked - alreadyClaimed;
    }

    function unlockedAmount(
        uint256 roundId,
        address user
    ) public view returns (uint256) {
        user;

        if (!_roundExists(roundId)) revert RoundDoesNotExist();

        Round memory round = rounds[roundId];

        if (!round.active) {
            return 0;
        }

        if (tgeTimestamp == 0 || block.timestamp < tgeTimestamp) {
            return 0;
        }

        if (block.timestamp < round.roundStartTime) {
            return 0;
        }

        uint256 initialUnlock = (REWARD_PER_WALLET * INITIAL_UNLOCK_BPS) /
            BPS_DENOMINATOR;

        uint256 vestedPortion = REWARD_PER_WALLET - initialUnlock;

        uint256 elapsed = block.timestamp - uint256(tgeTimestamp);

        if (elapsed >= VESTING_DURATION) {
            return REWARD_PER_WALLET;
        }

        uint256 vestedUnlocked = (vestedPortion * elapsed) / VESTING_DURATION;

        return initialUnlock + vestedUnlocked;
    }

    function verify(
        uint256 roundId,
        address user,
        bytes32[] calldata proof
    ) external view returns (bool) {
        if (!_roundExists(roundId)) revert RoundDoesNotExist();

        return _verify(roundId, user, proof, rounds[roundId].merkleRoot);
    }

    function walletInfo(
        uint256 roundId,
        address user
    )
        external
        view
        returns (
            bool roundExists_,
            bool roundActive,
            uint64 roundStartTime,
            uint64 tgeTime,
            uint256 totalAllocation,
            uint256 unlocked,
            uint256 alreadyClaimed,
            uint256 currentlyClaimable,
            uint256 remaining
        )
    {
        roundExists_ = _roundExists(roundId);

        if (!roundExists_) {
            return (
                false,
                false,
                0,
                tgeTimestamp,
                0,
                0,
                0,
                0,
                0
            );
        }

        Round memory round = rounds[roundId];

        roundActive = round.active;
        roundStartTime = round.roundStartTime;
        tgeTime = tgeTimestamp;
        totalAllocation = REWARD_PER_WALLET;
        unlocked = unlockedAmount(roundId, user);
        alreadyClaimed = claimed[roundId][user];
        currentlyClaimable = unlocked > alreadyClaimed
            ? unlocked - alreadyClaimed
            : 0;
        remaining = REWARD_PER_WALLET > alreadyClaimed
            ? REWARD_PER_WALLET - alreadyClaimed
            : 0;
    }

    function getRound(
        uint256 roundId
    )
        external
        view
        returns (
            bytes32 merkleRoot,
            uint64 roundStartTime,
            uint64 eligibleWallets,
            bool active,
            uint256 totalAllocation,
            uint256 totalClaimed,
            uint256 totalUnclaimedReserved
        )
    {
        if (!_roundExists(roundId)) revert RoundDoesNotExist();

        Round memory round = rounds[roundId];

        merkleRoot = round.merkleRoot;
        roundStartTime = round.roundStartTime;
        eligibleWallets = round.eligibleWallets;
        active = round.active;
        totalAllocation = uint256(round.eligibleWallets) * REWARD_PER_WALLET;
        totalClaimed = totalClaimedByRound[roundId];
        totalUnclaimedReserved = totalAllocation - totalClaimed;
    }

    function recoverableAXNV() external view returns (uint256) {
        uint256 balance = axnv.balanceOf(address(this));

        if (balance <= totalReservedUnclaimed) {
            return 0;
        }

        return balance - totalReservedUnclaimed;
    }

    function contractAXNVBalance() external view returns (uint256) {
        return axnv.balanceOf(address(this));
    }

    // =============================================================
    //                       INTERNAL FUNCTIONS
    // =============================================================

    function _verify(
        uint256 roundId,
        address user,
        bytes32[] calldata proof,
        bytes32 merkleRoot
    ) internal pure returns (bool) {
        bytes32 leaf = keccak256(abi.encode(roundId, user));

        return MerkleProof.verifyCalldata(proof, merkleRoot, leaf);
    }

    function _getValidRound(
        uint256 roundId
    ) internal view returns (Round memory round) {
        if (!_roundExists(roundId)) revert RoundDoesNotExist();

        round = rounds[roundId];

        if (!round.active) revert RoundNotActive();
    }

    function _roundExists(uint256 roundId) internal view returns (bool) {
        return roundId < nextRoundId;
    }

    function _checkAXNVBalance() internal view {
        if (axnv.balanceOf(address(this)) < totalReservedUnclaimed) {
            revert InsufficientAXNVBalance();
        }
    }
}
