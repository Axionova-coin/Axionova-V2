// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AXNVBaseVault.sol";

contract AXNVGovernanceVault is AXNVBaseVault {
    constructor(address axnv)
        AXNVBaseVault(axnv)
    {}
}
