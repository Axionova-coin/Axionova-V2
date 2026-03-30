// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MarketingVault
/// @notice Controlled vault for marketing, CEX, and operational spending.
/// @dev Rate-limited, owner-controlled, non-upgradeable.

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

contract MarketingVault {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event MarketingSpend(address indexed to, uint256 amount, string reason);
    event DailyLimitUpdated(uint256 newLimit);
    event TxLimitUpdated(uint256 newLimit);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable AXNV;
    address public owner;

    uint256 public dailyLimit;
    uint256 public txLimit;

    uint256 public spentToday;
    uint256 public lastSpendDay;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _axnv,
        address _owner,
        uint256 _dailyLimit,
        uint256 _txLimit
    ) {
        require(_axnv != address(0), "AXNV zero");
        require(_owner != address(0), "Owner zero");
        require(_txLimit <= _dailyLimit, "Tx > daily");

        AXNV = _axnv;
        owner = _owner;
        dailyLimit = _dailyLimit;
        txLimit = _txLimit;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _currentDay() internal view returns (uint256) {
        return block.timestamp / 1 days;
    }

    function _updateDailySpend(uint256 amount) internal {
        uint256 day = _currentDay();

        if (day != lastSpendDay) {
            lastSpendDay = day;
            spentToday = 0;
        }

        spentToday += amount;
        require(spentToday <= dailyLimit, "Daily limit exceeded");
    }

    /*//////////////////////////////////////////////////////////////
                        MARKETING WITHDRAWALS
    //////////////////////////////////////////////////////////////*/

    function withdraw(
        address to,
        uint256 amount,
        string calldata reason
    ) external onlyOwner {
        require(amount <= txLimit, "Tx limit exceeded");

        _updateDailySpend(amount);

        IERC20(AXNV).transfer(to, amount);

        emit MarketingSpend(to, amount, reason);
    }

    /*//////////////////////////////////////////////////////////////
                        LIMIT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function setDailyLimit(uint256 newLimit) external onlyOwner {
        require(newLimit >= txLimit, "Below tx limit");
        dailyLimit = newLimit;
        emit DailyLimitUpdated(newLimit);
    }

    function setTxLimit(uint256 newLimit) external onlyOwner {
        require(newLimit <= dailyLimit, "Above daily limit");
        txLimit = newLimit;
        emit TxLimitUpdated(newLimit);
    }

    /*//////////////////////////////////////////////////////////////
                        OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN RESCUE
    //////////////////////////////////////////////////////////////*/

    function rescueToken(address token) external onlyOwner {
        require(token != AXNV, "Cannot rescue AXNV");
        uint256 bal = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner, bal);
    }
}
