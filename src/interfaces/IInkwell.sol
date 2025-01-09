// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IInkwell {
    function buy(uint256 amount, address paymentToken) external returns (uint256);
}
