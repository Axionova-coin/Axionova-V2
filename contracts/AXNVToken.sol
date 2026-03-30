// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AXNVToken
 * @dev Core ERC20 token for Axionova V2.
 * Fixed supply. No minting. No burning. No fees.
 * All ecosystem logic lives outside this contract.
 */
contract AXNVToken is ERC20, Ownable {

    uint256 public constant TOTAL_SUPPLY = 750_000_000 * 10 ** 18;

    constructor()
		ERC20("Axionova", "AXNV")
	{
		_mint(msg.sender, TOTAL_SUPPLY);
	}
}
