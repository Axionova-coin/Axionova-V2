// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title LiquidityVault
/// @notice Holds AXNV tokens and manages time-locked liquidity provisioning.
/// @dev Single-purpose, non-upgradeable, auditor-friendly vault.

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
}

interface IUniswapV2Router02 {
    function factory() external view returns (address);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address);
}

contract LiquidityVault {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event RouterQueued(address indexed router, uint256 executeAfter);
    event RouterSet(address indexed router);

    event PairQueued(address indexed quoteToken, uint256 executeAfter);
    event PairActivated(address indexed quoteToken, address pair);

    event LiquidityAdded(address indexed quoteToken, uint256 axnvAmount, uint256 quoteAmount);
    event LiquidityRemovalQueued(address indexed quoteToken, uint256 executeAfter);
    event LiquidityRemoved(address indexed quoteToken);

    event EmergencyWithdrawQueued(address indexed token, uint256 executeAfter);
    event EmergencyWithdrawExecuted(address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable AXNV;
    address public immutable USDT;
    address public immutable WBNB;

    address public owner;
    address public router;

    uint256 public constant TIMELOCK = 24 hours;

    struct TimelockAction {
        uint256 executeAfter;
        bool exists;
    }

    mapping(bytes32 => TimelockAction) public timelocks;
    mapping(address => address) public pairForQuote; // quoteToken => pair

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
        address _usdt,
        address _wbnb,
        address _owner
    ) {
        require(_axnv != address(0) && _usdt != address(0) && _wbnb != address(0), "Zero address");
        require(_owner != address(0), "Owner zero");

        AXNV = _axnv;
        USDT = _usdt;
        WBNB = _wbnb;
        owner = _owner;
    }

    /*//////////////////////////////////////////////////////////////
                        ROUTER MANAGEMENT (TIMELOCKED)
    //////////////////////////////////////////////////////////////*/

    function queueSetRouter(address _router) external onlyOwner {
        require(_router != address(0), "Router zero");

        bytes32 key = keccak256("SET_ROUTER");
        timelocks[key] = TimelockAction(block.timestamp + TIMELOCK, true);

        emit RouterQueued(_router, block.timestamp + TIMELOCK);
    }

    function executeSetRouter(address _router) external onlyOwner {
        bytes32 key = keccak256("SET_ROUTER");
        TimelockAction memory action = timelocks[key];

        require(action.exists, "No queued action");
        require(block.timestamp >= action.executeAfter, "Timelock active");

        delete timelocks[key];
        router = _router;

        emit RouterSet(_router);
    }

    /*//////////////////////////////////////////////////////////////
                        PAIR REGISTRATION (TIMELOCKED)
    //////////////////////////////////////////////////////////////*/

    function queueAddPair(address quoteToken) external onlyOwner {
        require(quoteToken == USDT || quoteToken == WBNB, "Unsupported quote");

        bytes32 key = keccak256(abi.encode("ADD_PAIR", quoteToken));
        timelocks[key] = TimelockAction(block.timestamp + TIMELOCK, true);

        emit PairQueued(quoteToken, block.timestamp + TIMELOCK);
    }

    function executeAddPair(address quoteToken) external onlyOwner {
        bytes32 key = keccak256(abi.encode("ADD_PAIR", quoteToken));
        TimelockAction memory action = timelocks[key];

        require(action.exists, "No queued action");
        require(block.timestamp >= action.executeAfter, "Timelock active");
        require(router != address(0), "Router not set");

        delete timelocks[key];

        address pair = IUniswapV2Factory(IUniswapV2Router02(router).factory())
            .getPair(AXNV, quoteToken);

        require(pair != address(0), "Pair not created");

        pairForQuote[quoteToken] = pair;

        emit PairActivated(quoteToken, pair);
    }

    /*//////////////////////////////////////////////////////////////
                        LIQUIDITY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function addLiquidity(
        address quoteToken,
        uint256 axnvAmount,
        uint256 quoteAmount
    ) external onlyOwner {
        require(pairForQuote[quoteToken] != address(0), "Pair not active");

        IERC20(AXNV).approve(router, axnvAmount);
        IERC20(quoteToken).approve(router, quoteAmount);

        IUniswapV2Router02(router).addLiquidity(
            AXNV,
            quoteToken,
            axnvAmount,
            quoteAmount,
            0,
            0,
            address(this),
            block.timestamp
        );

        emit LiquidityAdded(quoteToken, axnvAmount, quoteAmount);
    }

    /*//////////////////////////////////////////////////////////////
                    LIQUIDITY REMOVAL (TIMELOCKED)
    //////////////////////////////////////////////////////////////*/

    function queueRemoveLiquidity(address quoteToken) external onlyOwner {
        require(pairForQuote[quoteToken] != address(0), "Pair not active");

        bytes32 key = keccak256(abi.encode("REMOVE_LIQ", quoteToken));
        timelocks[key] = TimelockAction(block.timestamp + TIMELOCK, true);

        emit LiquidityRemovalQueued(quoteToken, block.timestamp + TIMELOCK);
    }

    function executeRemoveLiquidity(address quoteToken) external onlyOwner {
        bytes32 key = keccak256(abi.encode("REMOVE_LIQ", quoteToken));
        TimelockAction memory action = timelocks[key];

        require(action.exists, "No queued action");
        require(block.timestamp >= action.executeAfter, "Timelock active");

        delete timelocks[key];

        address pair = pairForQuote[quoteToken];
        uint256 lpBalance = IERC20(pair).balanceOf(address(this));

        IERC20(pair).approve(router, lpBalance);

        IUniswapV2Router02(router).removeLiquidity(
            AXNV,
            quoteToken,
            lpBalance,
            0,
            0,
            address(this),
            block.timestamp
        );

        emit LiquidityRemoved(quoteToken);
    }

    /*//////////////////////////////////////////////////////////////
                    EMERGENCY WITHDRAW (TIMELOCKED)
    //////////////////////////////////////////////////////////////*/

    function queueEmergencyWithdraw(address token) external onlyOwner {
        bytes32 key = keccak256(abi.encode("EMERGENCY", token));
        timelocks[key] = TimelockAction(block.timestamp + TIMELOCK, true);

        emit EmergencyWithdrawQueued(token, block.timestamp + TIMELOCK);
    }

    function executeEmergencyWithdraw(address token) external onlyOwner {
        bytes32 key = keccak256(abi.encode("EMERGENCY", token));
        TimelockAction memory action = timelocks[key];

        require(action.exists, "No queued action");
        require(block.timestamp >= action.executeAfter, "Timelock active");

        delete timelocks[key];

        uint256 bal = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner, bal);

        emit EmergencyWithdrawExecuted(token, bal);
    }

    /*//////////////////////////////////////////////////////////////
                        OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero owner");
        owner = newOwner;
    }
}
