// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

interface IStrategyBuilderPlugin {
    enum FunctionId {USER_OP_VALIDATION_SESSION_KEY}

    enum ActionType {
        EXTERNAL,
        INTERNAL_ACTION
    }

    /* ====== Structs ====== */

    struct Action {
        bytes4 selector;
        bytes parameter;
        address target;
        uint256 value;
        ActionType actionType;
    }

    struct Condition {
        address conditionAddress;
        uint16 id;
        uint16 result1; // If the condition returns 1 got to index result1. If index result1 is 0 then no next step
        uint16 result0; // If the condtions returns 0 go to index result0. If index result0 is 0 then no next step
    }

    struct StrategyStep {
        Condition condition;
        Action[] actions;
    }

    struct Strategy {
        address creator;
        StrategyStep[] steps;
    }

    struct Automation {
        Condition condition; // If the condition returns 1, the automation can be executed
        uint16 strategyId;
        address paymentToken;
        uint256 maxFeeAmount;
    }

    /* ====== Events ====== */

    event StrategyAdded(uint16 strategyId, address creator, Strategy strategy);
    event StrategyExecuted(uint16 strategyId);
    event StrategyDeleted(uint16 strategyId);

    event AutomationActivated(
        uint16 automationId, uint16 strategyId, Condition condition, address paymentToken, uint256 maxFeeAmount
    );
    event AutomationDeleted(uint16 automationId);
    event AutomationExecuted(uint16 automationId, address paymentToken, uint256 feeAmount);

    event StrategyStepExecuted(uint16 strategyId, uint16 stepId, Action[] actions);

    function addStrategy(uint16 id, address creator, StrategyStep[] calldata steps) external;

    // function executeStrategy(uint16 id) external;

    // function deleteStrategy(uint16 id) external;

    // function activateAutomation(
    //     uint16 id,
    //     uint16 strategyId,
    //     Condition calldata condition,
    //     address paymentToken,
    //     uint256 maxFeeAmount
    // ) external;

    // function executeAutomation(uint16 id, address beneficary) external;

    // function strategy(uint16 strategyId) external view returns (Strategy memory);

    // function automation(uint16 automationId) external view returns (Automation memory);
}
