// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract GameIncentivesVault {
    IERC20 public immutable axnv;
    address public owner;

    uint256 public immutable startTime;
    uint256 public constant EPOCH_LENGTH = 7 days;

    uint256 public maxWeeklyEmission;
    mapping(uint256 => uint256) public emittedPerEpoch;
    mapping(address => bool) public authorizedSpender;

    event SpenderAuthorized(address spender, bool status);
    event WeeklyCapUpdated(uint256 newCap);
    event Emission(uint256 indexed epoch, address indexed to, uint256 amount);
    event OwnershipTransferred(address oldOwner, address newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    modifier onlySpender() {
        require(authorizedSpender[msg.sender], "NOT_AUTHORIZED");
        _;
    }

    constructor(address _axnv, uint256 _maxWeeklyEmission) {
        axnv = IERC20(_axnv);
        owner = msg.sender;
        startTime = block.timestamp;
        maxWeeklyEmission = _maxWeeklyEmission;
    }

    function currentEpoch() public view returns (uint256) {
        return (block.timestamp - startTime) / EPOCH_LENGTH;
    }

    function setWeeklyEmissionCap(uint256 cap) external onlyOwner {
        maxWeeklyEmission = cap;
        emit WeeklyCapUpdated(cap);
    }

    function setAuthorizedSpender(address spender, bool status) external onlyOwner {
        authorizedSpender[spender] = status;
        emit SpenderAuthorized(spender, status);
    }

    function emitRewards(address to, uint256 amount) external onlySpender {
        uint256 epoch = currentEpoch();
        uint256 newTotal = emittedPerEpoch[epoch] + amount;
        require(newTotal <= maxWeeklyEmission, "WEEKLY_CAP_EXCEEDED");

        emittedPerEpoch[epoch] = newTotal;
        require(axnv.transfer(to, amount), "TRANSFER_FAILED");

        emit Emission(epoch, to, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_ADDRESS");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
