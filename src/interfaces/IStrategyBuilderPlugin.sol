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
        uint32 id;
        uint8 result1; // If the condition returns 1 got to index result1. If index result1 is 0 then no next step
        uint8 result0; // If the condtions returns 0 go to index result0. If index result0 is 0 then no next step
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
        uint32 strategyId;
        address paymentToken;
        uint256 maxFeeAmount;
    }

    error StrategyDoesNotExist();
    error StrategyAlreadyExist();
    error AutomationNotExecutable(address condition, uint32 id);
    error FeeExceedMaxFee();
    error AutomationNotExist();
    error AutomationAlreadyExist();
    error StrategyIsInUse();
    error changeAutomationInConditionFailed();
    error ChangeStrategyInConditionFailed();
    error UpdateConditionFailed(address condition, uint32 id);
    error PaymentTokenNotAllowed();

    /* ====== Events ====== */

    event StrategyCreated(address indexed wallet, uint32 strategyId, address creator, Strategy strategy);
    event StrategyExecuted(address indexed wallet, uint32 strategyId);
    event StrategyDeleted(address indexed wallet, uint32 strategyId);

    event AutomationCreated(
        address indexed wallet,
        uint32 automationId,
        uint32 strategyId,
        Condition condition,
        address paymentToken,
        uint256 maxFeeAmount
    );
    event AutomationDeleted(address indexed wallet, uint32 automationId);
    event AutomationExecuted(
        address indexed wallet, uint32 automationId, address paymentToken, uint256 feeInToken, uint256 feeInUSD
    );

    event StrategyStepExecuted(address indexed wallet, uint32 strategyId, uint32 stepId, Action[] actions);
    event ActionExecuted(address indexed wallet, Action action);

    function createStrategy(uint32 id, address creator, StrategyStep[] calldata steps) external;
    function createAutomation(
        uint32 id,
        uint32 strategyId,
        address paymentToken,
        uint256 maxFeeInUSD,
        Condition calldata condition
    ) external;

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
