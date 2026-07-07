// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    AXNV Presale + Vesting Contract

    Network: BSC
    AXNV: 0xaFdEC2E212E771B758C75bE31f14F008F158DED7
    USDT: 0x55d398326f99059fF775485246999027B3197955

    Presale:
    - Users buy AXNV allocation using USDT.
    - AXNV is not transferred immediately.
    - Users claim AXNV through vesting after TGE.

    Vesting:
    - 20% unlock at TGE
    - 20% unlock at TGE + 90 days
    - 20% unlock at TGE + 180 days
    - 20% unlock at TGE + 270 days
    - 20% unlock at TGE + 360 days
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract AXNVPresaleVesting is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public constant AXNV =
        IERC20(0xaFdEC2E212E771B758C75bE31f14F008F158DED7);

    IERC20 public constant USDT =
        IERC20(0x55d398326f99059fF775485246999027B3197955);

    address public constant AXNV_ADDRESS =
        0xaFdEC2E212E771B758C75bE31f14F008F158DED7;

    address public constant USDT_ADDRESS =
        0x55d398326f99059fF775485246999027B3197955;

    uint256 public constant VESTING_INTERVAL = 90 days;
    uint256 public constant VESTING_STEPS = 5;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    uint8 public immutable axnvDecimals;
    uint8 public immutable usdtDecimals;

    uint256 public immutable PRESALE_SUPPLY;

    /*
        Prices are stored as USDT smallest units per 1 whole AXNV.

        Assuming BSC USDT has 18 decimals:
        Phase 1: 0.005 USDT  = 5_000_000_000_000_000
        Phase 2: 0.0075 USDT = 7_500_000_000_000_000
        Phase 3: 0.01 USDT   = 10_000_000_000_000_000
    */
    uint256[3] public phasePrices;

    uint8 public currentPhase;

    bool public presaleActive;
    bool public saleEnded;

    uint256 public tgeTimestamp;

    uint256 public totalAXNVSold;
    uint256 public totalUSDTRaised;
    uint256 public totalAXNVClaimed;

    struct BuyerInfo {
        uint256 purchasedAXNV;
        uint256 spentUSDT;
        uint256 claimedAXNV;
        uint256 purchaseCount;
        uint256 lastPurchaseTime;
    }

    mapping(address => BuyerInfo) private buyers;

    event TokensPurchased(
        address indexed buyer,
        uint256 usdtAmount,
        uint256 axnvAmount,
        uint8 indexed phase,
        uint256 price
    );

    event TokensClaimed(address indexed user, uint256 amount);

    event PhaseChanged(uint8 indexed oldPhase, uint8 indexed newPhase);

    event PresaleStatusChanged(bool active);

    event SaleEnded();

    event TGEUpdated(uint256 indexed tgeTimestamp);

    event USDTWithdrawn(address indexed to, uint256 amount);

    event UnsoldAXNVWithdrawn(address indexed to, uint256 amount);

    event RescueToken(address indexed token, address indexed to, uint256 amount);

    constructor() Ownable() {
        axnvDecimals = IERC20Metadata(AXNV_ADDRESS).decimals();
        usdtDecimals = IERC20Metadata(USDT_ADDRESS).decimals();

        PRESALE_SUPPLY = 262_500_000 * (10 ** uint256(axnvDecimals));

        phasePrices[0] = 5 * (10 ** uint256(usdtDecimals)) / 1000; // 0.005 USDT
        phasePrices[1] = 75 * (10 ** uint256(usdtDecimals)) / 10000; // 0.0075 USDT
        phasePrices[2] = 1 * (10 ** uint256(usdtDecimals)) / 100; // 0.01 USDT

        currentPhase = 0;
        presaleActive = true;
    }

    // ------------------------------------------------------------
    // Buy Logic
    // ------------------------------------------------------------

    function buy(uint256 usdtAmount) external nonReentrant whenNotPaused {
        require(presaleActive, "Presale is not active");
        require(!saleEnded, "Sale has ended");
        require(usdtAmount > 0, "USDT amount must be greater than zero");

        if (tgeTimestamp != 0) {
            require(block.timestamp < tgeTimestamp, "Buying after TGE is disabled");
        }

        uint256 axnvAmount = calculateAXNVAmount(usdtAmount);
		require(axnvAmount > 0, "AXNV amount is zero");
		require(
			totalAXNVSold + axnvAmount <= PRESALE_SUPPLY,
			"Presale supply exceeded"
		);
		require(
			AXNV.balanceOf(address(this)) >= totalAXNVSold + axnvAmount,
			"Insufficient AXNV funded"
		);

		USDT.safeTransferFrom(msg.sender, address(this), usdtAmount);

        BuyerInfo storage buyer = buyers[msg.sender];

        buyer.purchasedAXNV += axnvAmount;
        buyer.spentUSDT += usdtAmount;
        buyer.purchaseCount += 1;
        buyer.lastPurchaseTime = block.timestamp;

        totalAXNVSold += axnvAmount;
        totalUSDTRaised += usdtAmount;

        emit TokensPurchased(
            msg.sender,
            usdtAmount,
            axnvAmount,
            currentPhase,
            getCurrentPrice()
        );
    }

    function calculateAXNVAmount(uint256 usdtAmount) public view returns (uint256) {
        uint256 price = getCurrentPrice();

        /*
            axnvAmount = usdtAmount / price

            Because price is USDT smallest units per 1 whole AXNV,
            multiply by AXNV decimals first.
        */
        return (usdtAmount * (10 ** uint256(axnvDecimals))) / price;
    }

    function previewBuy(uint256 usdtAmount) external view returns (uint256 axnvAmount) {
        return calculateAXNVAmount(usdtAmount);
    }

    // ------------------------------------------------------------
    // Claim Logic
    // ------------------------------------------------------------

    function claim() external nonReentrant {
        require(tgeTimestamp != 0, "TGE is not set");
        require(block.timestamp >= tgeTimestamp, "TGE has not started");

        uint256 amount = claimableAmount(msg.sender);
        require(amount > 0, "Nothing to claim");

        BuyerInfo storage buyer = buyers[msg.sender];

        buyer.claimedAXNV += amount;
        totalAXNVClaimed += amount;

        AXNV.safeTransfer(msg.sender, amount);

        emit TokensClaimed(msg.sender, amount);
    }

    function claimableAmount(address user) public view returns (uint256) {
        uint256 unlocked = unlockedAmount(user);
        uint256 claimed = buyers[user].claimedAXNV;

        if (unlocked <= claimed) {
            return 0;
        }

        return unlocked - claimed;
    }

    function unlockedAmount(address user) public view returns (uint256) {
        uint256 purchased = buyers[user].purchasedAXNV;

        if (purchased == 0) {
            return 0;
        }

        if (tgeTimestamp == 0 || block.timestamp < tgeTimestamp) {
            return 0;
        }

        uint256 elapsed = block.timestamp - tgeTimestamp;

        uint256 stepsUnlocked = 1 + (elapsed / VESTING_INTERVAL);

        if (stepsUnlocked > VESTING_STEPS) {
            stepsUnlocked = VESTING_STEPS;
        }

        return (purchased * stepsUnlocked) / VESTING_STEPS;
    }

    function lockedAmount(address user) external view returns (uint256) {
        uint256 purchased = buyers[user].purchasedAXNV;
        uint256 unlocked = unlockedAmount(user);

        if (purchased <= unlocked) {
            return 0;
        }

        return purchased - unlocked;
    }

    function claimedAmount(address user) external view returns (uint256) {
        return buyers[user].claimedAXNV;
    }

    function nextUnlockInfo(
        address user
    ) external view returns (
        uint256 nextUnlockTimestamp,
        uint256 nextUnlockAmount
    ) {
        uint256 purchased = buyers[user].purchasedAXNV;

        if (purchased == 0 || tgeTimestamp == 0) {
            return (0, 0);
        }

        if (block.timestamp < tgeTimestamp) {
            return (tgeTimestamp, purchased / VESTING_STEPS);
        }

        uint256 elapsed = block.timestamp - tgeTimestamp;
        uint256 currentStep = 1 + (elapsed / VESTING_INTERVAL);

        if (currentStep >= VESTING_STEPS) {
            return (0, 0);
        }

        nextUnlockTimestamp = tgeTimestamp + (currentStep * VESTING_INTERVAL);
        nextUnlockAmount = purchased / VESTING_STEPS;
    }

    function getVestingSchedule(
        address user
    )
        external
        view
        returns (
            uint256[5] memory unlockTimestamps,
            uint256[5] memory unlockPercentsBps,
            uint256[5] memory unlockAmounts,
            bool[5] memory isUnlocked
        )
    {
        uint256 purchased = buyers[user].purchasedAXNV;

        for (uint256 i = 0; i < VESTING_STEPS; i++) {
            if (tgeTimestamp == 0) {
                unlockTimestamps[i] = 0;
                isUnlocked[i] = false;
            } else {
                unlockTimestamps[i] = tgeTimestamp + (i * VESTING_INTERVAL);
                isUnlocked[i] = block.timestamp >= unlockTimestamps[i];
            }

            unlockPercentsBps[i] = 2000; // 20%
            unlockAmounts[i] = purchased / VESTING_STEPS;
        }
    }

    // ------------------------------------------------------------
    // User Dashboard Views
    // ------------------------------------------------------------

    function getBuyerInfo(
        address user
    )
        external
        view
        returns (
            uint256 purchasedAXNV,
            uint256 spentUSDT,
            uint256 claimedAXNV,
            uint256 claimableAXNV,
            uint256 unlockedAXNV,
            uint256 lockedAXNV,
            uint256 purchaseCount,
            uint256 lastPurchaseTime
        )
    {
        BuyerInfo memory buyer = buyers[user];

        uint256 unlocked = unlockedAmount(user);
        uint256 claimable = claimableAmount(user);

        uint256 locked = 0;
        if (buyer.purchasedAXNV > unlocked) {
            locked = buyer.purchasedAXNV - unlocked;
        }

        return (
            buyer.purchasedAXNV,
            buyer.spentUSDT,
            buyer.claimedAXNV,
            claimable,
            unlocked,
            locked,
            buyer.purchaseCount,
            buyer.lastPurchaseTime
        );
    }

    function getPresaleInfo()
        external
        view
        returns (
            bool active,
            bool ended,
            bool paused_,
            uint8 phase,
            uint256 currentPrice,
            uint256 presaleSupply,
            uint256 sold,
            uint256 remaining,
            uint256 usdtRaised,
            uint256 tge
        )
    {
        return (
            presaleActive,
            saleEnded,
            paused(),
            currentPhase,
            getCurrentPrice(),
            PRESALE_SUPPLY,
            totalAXNVSold,
            remainingPresaleSupply(),
            totalUSDTRaised,
            tgeTimestamp
        );
    }

    function remainingPresaleSupply() public view returns (uint256) {
        if (totalAXNVSold >= PRESALE_SUPPLY) {
            return 0;
        }

        return PRESALE_SUPPLY - totalAXNVSold;
    }

    function reservedAXNV() public view returns (uint256) {
        if (totalAXNVSold <= totalAXNVClaimed) {
            return 0;
        }

        return totalAXNVSold - totalAXNVClaimed;
    }

    function availableAXNVBalance() public view returns (uint256) {
        uint256 balance = AXNV.balanceOf(address(this));
        uint256 reserved = reservedAXNV();

        if (balance <= reserved) {
            return 0;
        }

        return balance - reserved;
    }

    function contractAXNVBalance() external view returns (uint256) {
        return AXNV.balanceOf(address(this));
    }

    function contractUSDTBalance() external view returns (uint256) {
        return USDT.balanceOf(address(this));
    }

    function userUSDTBalance(address user) external view returns (uint256) {
        return USDT.balanceOf(user);
    }

    function userAXNVBalance(address user) external view returns (uint256) {
        return AXNV.balanceOf(user);
    }

    function userUSDTAllowance(address user) external view returns (uint256) {
        return USDT.allowance(user, address(this));
    }

    // ------------------------------------------------------------
    // Admin Functions
    // ------------------------------------------------------------

    function setPhase(uint8 newPhase) external onlyOwner {
        require(newPhase < 3, "Invalid phase");

        uint8 oldPhase = currentPhase;
        currentPhase = newPhase;

        emit PhaseChanged(oldPhase, newPhase);
    }

    function setPresaleActive(bool active) external onlyOwner {
        require(!saleEnded, "Sale already ended");

        presaleActive = active;

        emit PresaleStatusChanged(active);
    }

    function endSale() external onlyOwner {
        saleEnded = true;
        presaleActive = false;

        emit SaleEnded();
    }

    function setTGE(uint256 newTgeTimestamp) external onlyOwner {
        require(newTgeTimestamp > 0, "Invalid TGE timestamp");

        tgeTimestamp = newTgeTimestamp;

        if (block.timestamp >= newTgeTimestamp) {
            saleEnded = true;
            presaleActive = false;
            emit SaleEnded();
        }

        emit TGEUpdated(newTgeTimestamp);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawUSDT(address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid receiver");
        require(amount > 0, "Invalid amount");

        USDT.safeTransfer(to, amount);

        emit USDTWithdrawn(to, amount);
    }

    function withdrawAllUSDT(address to) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid receiver");

        uint256 amount = USDT.balanceOf(address(this));
        require(amount > 0, "No USDT to withdraw");

        USDT.safeTransfer(to, amount);

        emit USDTWithdrawn(to, amount);
    }

    function withdrawUnsoldAXNV(
        address to,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid receiver");
        require(amount > 0, "Invalid amount");

        uint256 available = availableAXNVBalance();
        require(amount <= available, "Amount exceeds unreserved AXNV");

        AXNV.safeTransfer(to, amount);

        emit UnsoldAXNVWithdrawn(to, amount);
    }

    function rescueToken(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(token != AXNV_ADDRESS, "Use withdrawUnsoldAXNV for AXNV");
        require(token != USDT_ADDRESS, "Use withdrawUSDT for USDT");
        require(to != address(0), "Invalid receiver");
        require(amount > 0, "Invalid amount");

        IERC20(token).safeTransfer(to, amount);

        emit RescueToken(token, to, amount);
    }

    // ------------------------------------------------------------
    // Price Views
    // ------------------------------------------------------------

    function getCurrentPrice() public view returns (uint256) {
        return phasePrices[currentPhase];
    }

    function getPhasePrices() external view returns (uint256[3] memory) {
        return phasePrices;
    }
}
