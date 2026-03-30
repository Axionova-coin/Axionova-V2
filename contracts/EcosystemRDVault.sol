// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

contract EcosystemRDVault {
    IERC20 public immutable axnv;
    address public governor;
    address public admin;

    uint256 public immutable startTime;
    uint256 public constant CLIFF = 90 days;
    uint256 public constant PERIOD = 30 days;

    uint256 public ecosystemReleased;
    uint256 public rdReleased;

    bool public rescueDisabled;
    uint256 public rescueQueuedAt;
    uint256 public constant RESCUE_DELAY = 72 hours;
    address public immutable rescueDestination;

    modifier onlyGovernor() {
        require(msg.sender == governor, "Not governor");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor(
        address _axnv,
        address _admin,
        address _rescueDestination
    ) {
        axnv = IERC20(_axnv);
        admin = _admin;
        rescueDestination = _rescueDestination;
        startTime = block.timestamp;
    }

    function setGovernor(address _governor) external onlyAdmin {
        require(governor == address(0), "Governor already set");
        governor = _governor;
    }

    function renounceAdmin() external onlyAdmin {
        admin = address(0);
    }

    function _vestedAmount(uint256 total) internal view returns (uint256) {
        if (block.timestamp < startTime + CLIFF) return 0;
        uint256 elapsed = block.timestamp - (startTime + CLIFF);
        uint256 periods = elapsed / PERIOD + 1;
        uint256 maxPeriods = 24;
        if (periods > maxPeriods) periods = maxPeriods;
        return (total * periods) / maxPeriods;
    }

    function availableEcosystem() public view returns (uint256) {
        uint256 total = axnv.balanceOf(address(this)) + ecosystemReleased + rdReleased;
        uint256 vested = _vestedAmount(total);
        if (vested <= ecosystemReleased) return 0;
        return vested - ecosystemReleased;
    }

    function availableRD() public view returns (uint256) {
        uint256 total = axnv.balanceOf(address(this)) + ecosystemReleased + rdReleased;
        uint256 vested = _vestedAmount(total);
        if (vested <= rdReleased) return 0;
        return vested - rdReleased;
    }

    function releaseEcosystem(address to, uint256 amount) external onlyGovernor {
        require(amount <= availableEcosystem(), "Exceeds available");
        ecosystemReleased += amount;
        axnv.transfer(to, amount);
    }

    function releaseRD(address to, uint256 amount) external onlyGovernor {
        require(amount <= availableRD(), "Exceeds available");
        rdReleased += amount;
        axnv.transfer(to, amount);
    }

    function queueEmergencyRescue() external onlyGovernor {
        require(!rescueDisabled, "Rescue disabled");
        rescueQueuedAt = block.timestamp;
    }

    function executeEmergencyRescue() external onlyGovernor {
        require(!rescueDisabled, "Rescue disabled");
        require(rescueQueuedAt != 0, "Not queued");
        require(block.timestamp >= rescueQueuedAt + RESCUE_DELAY, "Delay not passed");

        uint256 balance = axnv.balanceOf(address(this));
        axnv.transfer(rescueDestination, balance);
        rescueQueuedAt = 0;
    }

    function disableEmergencyRescue() external onlyGovernor {
        rescueDisabled = true;
    }
}
