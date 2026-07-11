// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract AXNVPresaleVesting is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public constant AXNV =
        IERC20(0x0c9c7B3e3D7F95F6f52F805250AFa7D2E335AeFD);

    IERC20 public constant USDT =
        IERC20(0x55d398326f99059fF775485246999027B3197955);

    address public constant AXNV_ADDRESS =
        0x0c9c7B3e3D7F95F6f52F805250AFa7D2E335AeFD;

    address public constant USDT_ADDRESS =
        0x55d398326f99059fF775485246999027B3197955;

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant TGE_UNLOCK_BPS = 1_500; // 15%
    uint256 public constant VESTING_DURATION = 365 days; // 12 months

    uint8 public constant PHASE_COUNT = 3;

    uint8 public immutable axnvDecimals;
    uint8 public immutable usdtDecimals;

    uint256 public immutable PRESALE_SUPPLY;

    uint256[3] public phasePrices;
    uint256[3] public phaseSupplies;
    uint256[3] public phaseSold;

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
        uint8 indexed phaseAfterPurchase
    );

    event TokensClaimed(address indexed user, uint256 amount);
    event PhaseChanged(uint8 indexed oldPhase, uint8 indexed newPhase);
    event PresaleStarted();
    event PresaleStopped();
    event SaleEnded();
    event TGEUpdated(uint256 indexed tgeTimestamp);
    event USDTWithdrawn(address indexed to, uint256 amount);
    event UnsoldAXNVWithdrawn(address indexed to, uint256 amount);
    event RescueToken(address indexed token, address indexed to, uint256 amount);

    constructor(address initialOwner) Ownable(initialOwner) {
        require(initialOwner != address(0), "Invalid owner");

        axnvDecimals = IERC20Metadata(AXNV_ADDRESS).decimals();
        usdtDecimals = IERC20Metadata(USDT_ADDRESS).decimals();

        PRESALE_SUPPLY = 262_500_000 * (10 ** uint256(axnvDecimals));

        phaseSupplies[0] = 87_500_000 * (10 ** uint256(axnvDecimals));
        phaseSupplies[1] = 87_500_000 * (10 ** uint256(axnvDecimals));
        phaseSupplies[2] = 87_500_000 * (10 ** uint256(axnvDecimals));

        // BSC USDT has 18 decimals.
        // Phase 1: 0.005 USDT
        // Phase 2: 0.0075 USDT
        // Phase 3: 0.01 USDT
        phasePrices[0] = (5 * (10 ** uint256(usdtDecimals))) / 1000;
        phasePrices[1] = (75 * (10 ** uint256(usdtDecimals))) / 10000;
        phasePrices[2] = (1 * (10 ** uint256(usdtDecimals))) / 100;

        currentPhase = 0;
        presaleActive = false;
        saleEnded = false;
    }

    // ------------------------------------------------------------
    // Buy Logic
    // ------------------------------------------------------------

    function buy(uint256 usdtAmount) external nonReentrant whenNotPaused {
        require(presaleActive, "Presale is not active");
        require(!saleEnded, "Sale has ended");
        require(usdtAmount > 0, "Invalid USDT amount");
        require(totalAXNVSold < PRESALE_SUPPLY, "Sold out");

        if (tgeTimestamp != 0) {
            require(block.timestamp < tgeTimestamp, "Buying after TGE disabled");
        }

        uint256 remainingUSDT = usdtAmount;
        uint256 totalAXNVToBuy = 0;

        while (remainingUSDT > 0 && currentPhase < PHASE_COUNT) {
            uint256 phaseRemaining =
                phaseSupplies[currentPhase] - phaseSold[currentPhase];

            if (phaseRemaining == 0) {
                _advancePhase();
                continue;
            }

            uint256 price = phasePrices[currentPhase];

            uint256 axnvFromRemainingUSDT =
                (remainingUSDT * (10 ** uint256(axnvDecimals))) / price;

            if (axnvFromRemainingUSDT == 0) {
                break;
            }

            if (axnvFromRemainingUSDT <= phaseRemaining) {
                uint256 usdtUsed =
                    (axnvFromRemainingUSDT * price) /
                    (10 ** uint256(axnvDecimals));

                phaseSold[currentPhase] += axnvFromRemainingUSDT;
                totalAXNVToBuy += axnvFromRemainingUSDT;
                remainingUSDT -= usdtUsed;

                if (phaseSold[currentPhase] == phaseSupplies[currentPhase]) {
                    _advancePhase();
                }

                break;
            } else {
                uint256 usdtUsed =
                    (phaseRemaining * price) /
                    (10 ** uint256(axnvDecimals));

                phaseSold[currentPhase] += phaseRemaining;
                totalAXNVToBuy += phaseRemaining;
                remainingUSDT -= usdtUsed;

                _advancePhase();
            }
        }

        require(totalAXNVToBuy > 0, "AXNV amount is zero");
        require(
            totalAXNVSold + totalAXNVToBuy <= PRESALE_SUPPLY,
            "Presale supply exceeded"
        );

        uint256 usdtActuallyUsed = usdtAmount - remainingUSDT;
        require(usdtActuallyUsed > 0, "No USDT used");

        require(
            AXNV.balanceOf(address(this)) >= reservedAXNV() + totalAXNVToBuy,
            "Insufficient AXNV funded"
        );

        USDT.safeTransferFrom(msg.sender, address(this), usdtActuallyUsed);

        BuyerInfo storage buyer = buyers[msg.sender];

        buyer.purchasedAXNV += totalAXNVToBuy;
        buyer.spentUSDT += usdtActuallyUsed;
        buyer.purchaseCount += 1;
        buyer.lastPurchaseTime = block.timestamp;

        totalAXNVSold += totalAXNVToBuy;
        totalUSDTRaised += usdtActuallyUsed;

        if (totalAXNVSold == PRESALE_SUPPLY) {
            saleEnded = true;
            presaleActive = false;
            emit SaleEnded();
        }

        emit TokensPurchased(
            msg.sender,
            usdtActuallyUsed,
            totalAXNVToBuy,
            currentPhase
        );
    }

    function quoteAXNVForUSDT(uint256 usdtAmount)
        external
        view
        returns (uint256)
    {
        return _quoteAXNVForUSDT(usdtAmount);
    }

    function quoteUSDTForAXNV(uint256 axnvAmount)
        external
        view
        returns (uint256)
    {
        require(axnvAmount > 0, "Invalid AXNV amount");

        uint256 remainingAXNV = axnvAmount;
        uint256 totalUSDT = 0;
        uint8 phase = currentPhase;

        while (remainingAXNV > 0 && phase < PHASE_COUNT) {
            uint256 phaseRemaining = phaseSupplies[phase] - phaseSold[phase];

            if (phaseRemaining == 0) {
                phase++;
                continue;
            }

            uint256 axnvUsed = remainingAXNV <= phaseRemaining
                ? remainingAXNV
                : phaseRemaining;

            totalUSDT +=
                (axnvUsed * phasePrices[phase]) /
                (10 ** uint256(axnvDecimals));

            remainingAXNV -= axnvUsed;
            phase++;
        }

        require(remainingAXNV == 0, "Not enough AXNV left");

        return totalUSDT;
    }

    function _quoteAXNVForUSDT(uint256 usdtAmount)
        internal
        view
        returns (uint256)
    {
        uint256 remainingUSDT = usdtAmount;
        uint256 totalAXNV = 0;
        uint8 phase = currentPhase;

        while (remainingUSDT > 0 && phase < PHASE_COUNT) {
            uint256 phaseRemaining = phaseSupplies[phase] - phaseSold[phase];

            if (phaseRemaining == 0) {
                phase++;
                continue;
            }

            uint256 price = phasePrices[phase];

            uint256 axnvFromUSDT =
                (remainingUSDT * (10 ** uint256(axnvDecimals))) / price;

            if (axnvFromUSDT == 0) {
                break;
            }

            if (axnvFromUSDT <= phaseRemaining) {
                totalAXNV += axnvFromUSDT;
                break;
            } else {
                uint256 usdtUsed =
                    (phaseRemaining * price) /
                    (10 ** uint256(axnvDecimals));

                totalAXNV += phaseRemaining;
                remainingUSDT -= usdtUsed;
                phase++;
            }
        }

        return totalAXNV;
    }

    // ------------------------------------------------------------
    // Claim Logic
    // ------------------------------------------------------------

    function claim() external nonReentrant whenNotPaused {
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
        uint256 vested = vestedAmount(user);
        uint256 claimed = buyers[user].claimedAXNV;

        if (vested <= claimed) {
            return 0;
        }

        return vested - claimed;
    }

    function vestedAmount(address user) public view returns (uint256) {
        uint256 purchased = buyers[user].purchasedAXNV;

        if (purchased == 0) {
            return 0;
        }

        if (tgeTimestamp == 0 || block.timestamp < tgeTimestamp) {
            return 0;
        }

        uint256 tgeUnlocked =
            (purchased * TGE_UNLOCK_BPS) / BPS_DENOMINATOR;

        uint256 vestingAmount = purchased - tgeUnlocked;
        uint256 elapsed = block.timestamp - tgeTimestamp;

        if (elapsed >= VESTING_DURATION) {
            return purchased;
        }

        uint256 linearUnlocked =
            (vestingAmount * elapsed) / VESTING_DURATION;

        return tgeUnlocked + linearUnlocked;
    }

    function lockedAmount(address user) external view returns (uint256) {
        uint256 purchased = buyers[user].purchasedAXNV;
        uint256 vested = vestedAmount(user);

        if (purchased <= vested) {
            return 0;
        }

        return purchased - vested;
    }

    function claimedAmount(address user) external view returns (uint256) {
        return buyers[user].claimedAXNV;
    }

    // ------------------------------------------------------------
    // Dashboard Views
    // ------------------------------------------------------------

    function getBuyerInfo(address user)
        external
        view
        returns (
            uint256 purchasedAXNV,
            uint256 spentUSDT,
            uint256 claimedAXNV,
            uint256 claimableAXNV,
            uint256 vestedAXNV,
            uint256 lockedAXNV,
            uint256 purchaseCount,
            uint256 lastPurchaseTime
        )
    {
        BuyerInfo memory buyer = buyers[user];

        uint256 vested = vestedAmount(user);
        uint256 claimable = claimableAmount(user);

        uint256 locked = buyer.purchasedAXNV > vested
            ? buyer.purchasedAXNV - vested
            : 0;

        return (
            buyer.purchasedAXNV,
            buyer.spentUSDT,
            buyer.claimedAXNV,
            claimable,
            vested,
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

    function getPhaseInfo()
        external
        view
        returns (
            uint256[3] memory prices,
            uint256[3] memory supplies,
            uint256[3] memory sold,
            uint8 phase
        )
    {
        return (phasePrices, phaseSupplies, phaseSold, currentPhase);
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

    function isSaleOpen() external view returns (bool) {
        return (
            presaleActive &&
            !saleEnded &&
            !paused() &&
            totalAXNVSold < PRESALE_SUPPLY &&
            (tgeTimestamp == 0 || block.timestamp < tgeTimestamp)
        );
    }

    function soldOut() public view returns (bool) {
        return totalAXNVSold >= PRESALE_SUPPLY;
    }

    // ------------------------------------------------------------
    // Admin Functions
    // ------------------------------------------------------------

    function startSale() external onlyOwner {
        require(!saleEnded, "Sale already ended");
        require(!presaleActive, "Sale already active");
        require(totalAXNVSold < PRESALE_SUPPLY, "Sold out");

        presaleActive = true;

        emit PresaleStarted();
    }

    function stopSale() external onlyOwner {
        require(presaleActive, "Sale not active");

        presaleActive = false;

        emit PresaleStopped();
    }

    function endSale() external onlyOwner {
        saleEnded = true;
        presaleActive = false;

        emit SaleEnded();
    }

    function setTGE(uint256 newTgeTimestamp) external onlyOwner {
        require(newTgeTimestamp > 0, "Invalid TGE timestamp");

        if (tgeTimestamp != 0) {
            require(block.timestamp < tgeTimestamp, "TGE already started");
        }

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

    function withdrawUSDT(address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
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

    function withdrawUnsoldAXNV(address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(to != address(0), "Invalid receiver");
        require(amount > 0, "Invalid amount");

        uint256 available = availableAXNVBalance();
        require(amount <= available, "Amount exceeds unreserved AXNV");

        AXNV.safeTransfer(to, amount);

        emit UnsoldAXNVWithdrawn(to, amount);
    }

    function withdrawAllUnsoldAXNV(address to)
        external
        onlyOwner
        nonReentrant
    {
        require(to != address(0), "Invalid receiver");

        uint256 amount = availableAXNVBalance();
        require(amount > 0, "No unsold AXNV");

        AXNV.safeTransfer(to, amount);

        emit UnsoldAXNVWithdrawn(to, amount);
    }

    function rescueToken(address token, address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(token != AXNV_ADDRESS, "Use withdrawUnsoldAXNV");
        require(token != USDT_ADDRESS, "Use withdrawUSDT");
        require(to != address(0), "Invalid receiver");
        require(amount > 0, "Invalid amount");

        IERC20(token).safeTransfer(to, amount);

        emit RescueToken(token, to, amount);
    }

    // ------------------------------------------------------------
    // Internal Phase Logic
    // ------------------------------------------------------------

    function _advancePhase() internal {
        if (currentPhase + 1 < PHASE_COUNT) {
            uint8 oldPhase = currentPhase;
            currentPhase += 1;

            emit PhaseChanged(oldPhase, currentPhase);
        }
    }

    // ------------------------------------------------------------
    // Price Views
    // ------------------------------------------------------------

    function getCurrentPrice() public view returns (uint256) {
        if (currentPhase >= PHASE_COUNT) {
            return phasePrices[PHASE_COUNT - 1];
        }

        return phasePrices[currentPhase];
    }
}
