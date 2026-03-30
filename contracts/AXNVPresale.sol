// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from,address to,uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract AXNVPresale {

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Phase {
        uint256 price;       // AXNV price in USDT (18 decimals)
        uint256 allocation;  // AXNV tokens allocated for this phase
        uint256 sold;        // AXNV sold in this phase
    }

    struct User {
        uint256 totalAllocated;
        uint256 totalClaimed;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public owner;

    IERC20 public immutable usdt;
    IERC20 public immutable axnv;

    Phase[] public salePhases;
    uint256 public activePhase;
    uint256 public totalSoldTokens;

    bool public presaleActive;

    mapping(address => User) public users;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event PhaseAdded(uint256 index, uint256 price, uint256 allocation);
    event PresaleActivated();
    event TokensPurchased(address indexed buyer, uint256 usdtAmount, uint256 axnvAmount);
    event ERC20Withdrawn(address token, address to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier saleLive() {
        require(presaleActive, "Presale inactive");
        require(salePhases.length > 0, "No phases");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _usdt, address _axnv) {
        require(_usdt != address(0) && _axnv != address(0), "Zero address");
        owner = msg.sender;
        usdt = IERC20(_usdt);
        axnv = IERC20(_axnv);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function addPhase(uint256 price, uint256 allocation) external onlyOwner {
        require(!presaleActive, "Already active");
        require(price > 0, "Invalid price");
        require(allocation > 0, "Invalid allocation");

        salePhases.push(
            Phase({
                price: price,
                allocation: allocation,
                sold: 0
            })
        );

        emit PhaseAdded(salePhases.length - 1, price, allocation);
    }

    function activatePresale() external onlyOwner {
        require(salePhases.length > 0, "No phases added");
        presaleActive = true;
        emit PresaleActivated();
    }

    /*//////////////////////////////////////////////////////////////
                            BUY FUNCTION
    //////////////////////////////////////////////////////////////*/
    function buy(uint256 usdtAmount) external saleLive {
        require(usdtAmount > 0, "Zero amount");

        Phase storage phase = salePhases[activePhase];

        uint256 axnvAmount = (usdtAmount * 1e18) / phase.price;
        require(phase.sold + axnvAmount <= phase.allocation, "Phase sold out");

        require(
            axnv.balanceOf(address(this)) >= axnvAmount,
            "Insufficient AXNV in presale"
        );

        bool success = usdt.transferFrom(msg.sender, address(this), usdtAmount);
        require(success, "USDT transfer failed");

        phase.sold += axnvAmount;
        totalSoldTokens += axnvAmount;

        users[msg.sender].totalAllocated += axnvAmount;

        emit TokensPurchased(msg.sender, usdtAmount, axnvAmount);

        if (phase.sold == phase.allocation && activePhase + 1 < salePhases.length) {
            activePhase++;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIM (FUTURE)
    //////////////////////////////////////////////////////////////*/
    function claim() external {
        revert("Claim not enabled");
    }

    function claimable(address) external pure returns (uint256) {
        return 0;
    }

    /*//////////////////////////////////////////////////////////////
                        EMERGENCY WITHDRAW
    //////////////////////////////////////////////////////////////*/
    function withdrawERC20(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "Zero address");
        IERC20(token).transfer(to, amount);
        emit ERC20Withdrawn(token, to, amount);
    }
}
