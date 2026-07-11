// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

contract AXNVTokenV3 is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, Ownable {
    uint256 public constant TOTAL_SUPPLY = 750_000_000 * 10 ** 18;

    constructor(address initialOwner)
        ERC20("Axionova", "AXNV")
        ERC20Permit("Axionova")
        Ownable(initialOwner)
    {
        require(initialOwner != address(0), "AXNV: zero owner");
        _mint(initialOwner, TOTAL_SUPPLY);
    }

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
