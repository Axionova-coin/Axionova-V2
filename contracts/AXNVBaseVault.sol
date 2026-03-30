// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract AXNVBaseVault is Ownable {
    IERC20 public immutable axnv;

    event AXNVTransferred(address indexed to, uint256 amount);
    event ERC20Rescued(address indexed token, address indexed to, uint256 amount);
    event NativeRescued(address indexed to, uint256 amount);

	constructor(address _axnv) {
		require(_axnv != address(0), "AXNV address zero");
		axnv = IERC20(_axnv);
	}

    /* =======================
       AXNV NORMAL TRANSFER
       ======================= */

    function transferAXNV(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        require(axnv.balanceOf(address(this)) >= amount, "Insufficient AXNV");

        axnv.transfer(to, amount);
        emit AXNVTransferred(to, amount);
    }

    /* =======================
       ERC20 RESCUE (NON-AXNV)
       ======================= */

    function rescueERC20(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(token != address(axnv), "Use transferAXNV");
        require(token != address(0), "Invalid token");
        require(to != address(0), "Invalid recipient");

        IERC20(token).transfer(to, amount);
        emit ERC20Rescued(token, to, amount);
    }

    /* =======================
       NATIVE BNB RESCUE
       ======================= */

    function rescueNative(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        require(address(this).balance >= amount, "Insufficient balance");

        to.transfer(amount);
        emit NativeRescued(to, amount);
    }

    receive() external payable {}
}
