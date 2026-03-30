// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AXNVBaseVault.sol";

contract AXNVBugBountyVault is AXNVBaseVault {
    constructor(address axnv)
        AXNVBaseVault(axnv)
    {}
}
