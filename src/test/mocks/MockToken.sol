// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint256 maxTokenSupply) ERC20(name, symbol) {
        _mint(msg.sender, maxTokenSupply);
    }

    function setDecimals(uint8 _newDecimals) external {
        _decimals = _newDecimals;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
