// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AXNVAirdrop is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    uint256 public constant AIRDROP_ALLOCATION = 4_000_000 ether;
    uint256 public constant REWARD_PER_WALLET = 200 ether;

    uint256 public constant INITIAL_UNLOCK_BPS = 5_000; // 50%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant VESTING_DURATION = 90 days;

    uint256 private constant MANUAL_RECIPIENT_MARKER = type(uint256).max;

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

    uint256 public totalAllocatedForRounds;
    uint256 public totalReservedUnclaimed;
    uint256 public totalAXNVClaimed;

    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => uint256)) public claimed;
    mapping(uint256 => uint256) public totalClaimedByRound;

    mapping(address => bool) public hasReceivedAirdrop;

    /*
        recipientRoundMarker:
        - 0 = no airdrop claim/mark yet
        - roundId + 1 = wallet claimed from this contract round
        - type(uint256).max = manually marked previous recipient
    */
    mapping(address => uint256) public recipientRoundMarker;

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
    error RoundAlreadyStarted();
    error InvalidProof();
    error NothingToClaim();
    error InvalidRecipient();
    error InvalidWalletCount();
    error InsufficientAXNVBalance();
    error CannotRecoverReservedAXNV();
    error InvalidUpdate();
    error AllocationExceeded();
    error AlreadyReceivedAirdrop();
    error InvalidArrayLength();

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

    event RoundActiveStatusUpdated(
        uint256 indexed roundId,
        bool active
    );

    event Claimed(
        uint256 indexed roundId,
        address indexed user,
        uint256 amount,
        uint256 totalClaimed
    );

    event PreviousRecipientMarked(address indexed user);
    event PreviousRecipientUnmarked(address indexed user);

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

    function createRound(
        bytes32 merkleRoot,
        uint64 roundStartTime,
        uint64 eligibleWallets,
        bool active
    ) external onlyOwner returns (uint256 roundId) {
        if (merkleRoot == bytes32(0)) revert InvalidMerkleRoot();
        if (eligibleWallets == 0) revert InvalidWalletCount();

        uint256 roundAllocation = uint256(eligibleWallets) * REWARD_PER_WALLET;

        if (totalAllocatedForRounds + roundAllocation > AIRDROP_ALLOCATION) {
            revert AllocationExceeded();
        }

        roundId = nextRoundId;
        nextRoundId++;

        rounds[roundId] = Round({
            merkleRoot: merkleRoot,
            roundStartTime: roundStartTime,
            eligibleWallets: eligibleWallets,
            active: active
        });

        totalAllocatedForRounds += roundAllocation;
        totalReservedUnclaimed += roundAllocation;

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

        if (block.timestamp >= round.roundStartTime) {
            revert RoundAlreadyStarted();
        }

        uint256 oldTotalAllocation =
            uint256(round.eligibleWallets) * REWARD_PER_WALLET;

        uint256 newTotalAllocation =
            uint256(eligibleWallets) * REWARD_PER_WALLET;

        if (
            totalAllocatedForRounds - oldTotalAllocation + newTotalAllocation >
            AIRDROP_ALLOCATION
        ) {
            revert AllocationExceeded();
        }

        uint256 alreadyClaimed = totalClaimedByRound[roundId];

        if (newTotalAllocation < alreadyClaimed) {
            revert InvalidUpdate();
        }

        uint256 oldUnclaimedReserve = oldTotalAllocation - alreadyClaimed;
        uint256 newUnclaimedReserve = newTotalAllocation - alreadyClaimed;

        totalAllocatedForRounds =
            totalAllocatedForRounds -
            oldTotalAllocation +
            newTotalAllocation;

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

    function setRoundActive(uint256 roundId, bool active) external onlyOwner {
        if (!_roundExists(roundId)) revert RoundDoesNotExist();

        rounds[roundId].active = active;

        if (active) {
            _checkAXNVBalance();
        }

        emit RoundActiveStatusUpdated(roundId, active);
    }

    function markPreviousRecipients(address[] calldata users) external onlyOwner {
        uint256 length = users.length;

        if (length == 0) revert InvalidArrayLength();

        for (uint256 i = 0; i < length; i++) {
            address user = users[i];

            if (user == address(0)) revert ZeroAddress();

            hasReceivedAirdrop[user] = true;
            recipientRoundMarker[user] = MANUAL_RECIPIENT_MARKER;

            emit PreviousRecipientMarked(user);
        }
    }

    function unmarkPreviousRecipients(address[] calldata users) external onlyOwner {
        uint256 length = users.length;

        if (length == 0) revert InvalidArrayLength();

        for (uint256 i = 0; i < length; i++) {
            address user = users[i];

            if (user == address(0)) revert ZeroAddress();

            if (recipientRoundMarker[user] == MANUAL_RECIPIENT_MARKER) {
                hasReceivedAirdrop[user] = false;
                recipientRoundMarker[user] = 0;

                emit PreviousRecipientUnmarked(user);
            }
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

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

    function claim(
        uint256 roundId,
        bytes32[] calldata proof
    ) external nonReentrant whenNotPaused {
        Round memory round = _getValidRound(roundId);

        if (tgeTimestamp == 0) revert TGENotSet();
        if (block.timestamp < tgeTimestamp) revert TGENotStarted();
        if (block.timestamp < round.roundStartTime) revert RoundNotStarted();

        uint256 marker = recipientRoundMarker[msg.sender];

        if (
            hasReceivedAirdrop[msg.sender] &&
            marker != roundId + 1
        ) {
            revert AlreadyReceivedAirdrop();
        }

        if (!_verify(roundId, msg.sender, proof, round.merkleRoot)) {
            revert InvalidProof();
        }

        uint256 amount = claimable(roundId, msg.sender);

        if (amount == 0) revert NothingToClaim();

        if (!hasReceivedAirdrop[msg.sender]) {
            hasReceivedAirdrop[msg.sender] = true;
            recipientRoundMarker[msg.sender] = roundId + 1;
        }

        claimed[roundId][msg.sender] += amount;
        totalClaimedByRound[roundId] += amount;
        totalAXNVClaimed += amount;
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

        uint256 initialUnlock =
            (REWARD_PER_WALLET * INITIAL_UNLOCK_BPS) /
            BPS_DENOMINATOR;

        uint256 vestedPortion = REWARD_PER_WALLET - initialUnlock;

        uint256 elapsed = block.timestamp - uint256(tgeTimestamp);

        if (elapsed >= VESTING_DURATION) {
            return REWARD_PER_WALLET;
        }

        uint256 vestedUnlocked =
            (vestedPortion * elapsed) /
            VESTING_DURATION;

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
            uint256 remaining,
            bool alreadyReceivedAirdrop
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
                0,
                hasReceivedAirdrop[user]
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

        alreadyReceivedAirdrop = hasReceivedAirdrop[user];
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

    function getAirdropInfo()
        external
        view
        returns (
            uint64 tgeTime,
            uint256 roundCount,
            uint256 airdropAllocation,
            uint256 allocatedForRounds,
            uint256 remainingAllocation,
            uint256 reservedUnclaimed,
            uint256 claimedTotal,
            uint256 contractBalance,
            uint256 recoverable,
            bool paused_
        )
    {
        tgeTime = tgeTimestamp;
        roundCount = nextRoundId;
        airdropAllocation = AIRDROP_ALLOCATION;
        allocatedForRounds = totalAllocatedForRounds;
        remainingAllocation = remainingAirdropAllocation();
        reservedUnclaimed = totalReservedUnclaimed;
        claimedTotal = totalAXNVClaimed;
        contractBalance = axnv.balanceOf(address(this));
        recoverable = recoverableAXNV();
        paused_ = paused();
    }

    function remainingAirdropAllocation() public view returns (uint256) {
        if (totalAllocatedForRounds >= AIRDROP_ALLOCATION) {
            return 0;
        }

        return AIRDROP_ALLOCATION - totalAllocatedForRounds;
    }

    function recoverableAXNV() public view returns (uint256) {
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
