// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

interface IQuarterlyVesting {
    function initialize(
        address beneficiary,
        address token,
        uint256 totalAmount,
        uint256 start
    ) external;
}

contract AXNVClaim {

    using Clones for address;

    IERC20 public immutable axnv;
    bytes32 public immutable merkleRoot;
    uint256 public immutable tgeTimestamp;
    address public immutable vestingImplementation;

    mapping(address => bool) public claimed;

    event Claimed(address indexed user, uint256 totalAmount, address vestingContract);

    constructor(
        address _axnv,
        bytes32 _merkleRoot,
        uint256 _tgeTimestamp,
        address _vestingImplementation
    ) {
        axnv = IERC20(_axnv);
        merkleRoot = _merkleRoot;
        tgeTimestamp = _tgeTimestamp;
        vestingImplementation = _vestingImplementation;
    }

    function claim(uint256 totalAllocation, bytes32[] calldata proof) external {
        require(!claimed[msg.sender], "Already claimed");
        require(block.timestamp >= tgeTimestamp, "TGE not started");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, totalAllocation));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");

        claimed[msg.sender] = true;

        uint256 instantAmount = (totalAllocation * 20) / 100;
        uint256 vestingAmount = totalAllocation - instantAmount;

        require(axnv.transfer(msg.sender, instantAmount), "Transfer failed");

        address clone = vestingImplementation.clone();

        IQuarterlyVesting(clone).initialize(
            msg.sender,
            address(axnv),
            vestingAmount,
            tgeTimestamp
        );

        require(axnv.transfer(clone, vestingAmount), "Vesting transfer failed");

        emit Claimed(msg.sender, totalAllocation, clone);
    }
}