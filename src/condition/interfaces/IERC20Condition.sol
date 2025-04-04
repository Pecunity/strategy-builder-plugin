// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IERC20Condition {
    enum Comparison {
        GREATER_THAN,
        LESS_THAN,
        EQUAL
    }

    struct Condition {
        address token;
        uint256 amount;
        Comparison comparison;
        address compToken;
        bool updateable;
    }
}
