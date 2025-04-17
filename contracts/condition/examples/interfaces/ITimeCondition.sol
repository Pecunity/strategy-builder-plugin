// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITimeCondition {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃            Errors                ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    error ExecutionTimeNotValid();
    error DeltaNotValid();
    error ConditionsIsNotUpdateable();

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃           Structs                ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    struct Condition {
        uint256 execution;
        uint256 delta;
        bool updateable;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃            Events                ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    event ConditionAdded(uint32 id, address wallet, Condition condition);
    event ConditionDeleted(uint32 id, address wallet);
    event ConditionUpdated(uint32 id, address wallet, uint256 newExecution);
}
