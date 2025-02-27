// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

interface IFeeController {
    struct FeeInfo {
        address token; // Token address
        uint256 percentage; // Fee percentage (e.g., 100 = 1%, 10000 = 100%)
        uint256 minFeeUSD; // Minimum fee in USD (scaled by 1e18)
    }
}
