// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


interface IFeeReduction {
    function getFeeReduction(address wallet) external view returns (uint256);
}