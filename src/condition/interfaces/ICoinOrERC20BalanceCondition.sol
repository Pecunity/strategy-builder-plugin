// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ICoinOrERC20BalanceCondition {
    enum Comparison {
        LESS,
        GREATER,
        EQUAL,
        GREATER_OR_EQUAL,
        LESS_OR_EQUAL,
        NOT_EQUAL
    }

    struct Condition {
        address baseToken;
        uint256 amount;
        Comparison comparison;
        bool updateable;
    }

    error InvalidComparison();

    event ConditionAdded(uint32 id, address wallet, Condition condition);
    event ConditionDeleted(uint32 id, address wallet);
}
