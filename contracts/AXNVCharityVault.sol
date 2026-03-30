// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AXNVBaseVault.sol";

contract AXNVCharityVault is AXNVBaseVault {
    constructor(address axnv)
        AXNVBaseVault(axnv)
    {}
}
