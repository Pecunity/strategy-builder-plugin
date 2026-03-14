// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITimerCondition {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃            Errors                ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    error DeltaNotValid();
    error ConditionsIsNotUpdateable();
    error TimerAlreadyActive();
    error TimerNotActive();
    error TimerNotFinished();

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃           Structs                ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    struct Condition {
        uint256 startTime;
        uint256 delta;
        bool active;
        bool updateable;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃            Events                ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    event ConditionAdded(uint32 id, address wallet, Condition condition);
    event ConditionDeleted(uint32 id, address wallet);
    event ConditionUpdated(uint32 id, address wallet, uint256 newExecution);
    event TimerStarted(uint32 id, address wallet, uint256 startTime);
}
