// SPDX-License-Identifier:MIT
pragma solidity ^0.8.26;

interface IStrategyBuilderPlugin {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃     Structs / Enums       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    enum FunctionId {
        USER_OP_VALIDATION_SESSION_KEY
    }

    /// @dev Enum for different types of actions in the strategy.
    /// @notice Enum representing the type of action in an automation strategy.
    enum ActionType {
        EXTERNAL, // External action interacting with external contracts.
        INTERNAL_ACTION // Internal action interacting with IAction contracts.

    }

    /// @dev Struct representing a single action in a strategy.
    /// @notice Defines an action to be executed as part of a strategy, including the selector, parameters, target address, value, and action type.
    struct Action {
        bytes4 selector; // The function selector for the action.
        bytes parameter; // The parameters to be passed to the action.
        address target; // The target address to which the action is directed.
        uint256 value; // The value (in wei) to be sent along with the action.
        ActionType actionType; // The type of action (external or internal).
    }

    /// @dev Struct defining a condition that must be met for a strategy or automation to be executed.
    /// @notice Represents a condition that will determine the execution flow in a strategy.
    struct Condition {
        address conditionAddress; // The address of the contract providing the condition.
        uint32 id; // The ID of the condition.
        uint8 result1; // The index to jump to if the condition returns 1.
        uint8 result0; // The index to jump to if the condition returns 0.
    }

    /// @dev Struct representing a single step in a strategy.
    /// @notice A strategy step includes a condition and associated actions to be executed.
    struct StrategyStep {
        Condition condition; // The condition that check if the actions in this step should executed.
        Action[] actions; // An array of actions to be executed if the condition is met.
    }

    /// @dev Struct representing a strategy, consisting of multiple steps.
    /// @notice Defines a strategy with its creator and the series of steps that make up the strategy.
    struct Strategy {
        address creator; // The address of the creator of the strategy.
        StrategyStep[] steps; // The steps that make up the strategy.
    }

    /// @dev Struct representing an automation process that can be executed based on a condition.
    /// @notice Defines an automation linked to a strategy, with a condition and payment details.
    struct Automation {
        Condition condition; // The condition that must return 1 for the automation to execute.
        uint32 strategyId; // The ID of the strategy associated with the automation.
        address paymentToken; // The token used to pay the execution fees.
        uint256 maxFeeAmount; // The maximum fee amount the user is willing to pay in the automation.
    }

    // ┏━━━━━━━━━━━━━━━━━┓
    // ┃    Errors       ┃
    // ┗━━━━━━━━━━━━━━━━━┛

    error InvalidID();
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
    error InvalidNextStepIndex();
    error InvalidActionTarget();
    error InvalidConditionAddress();
    error InvalidCondition();
    error PluginExecutionFailed();

    // ┏━━━━━━━━━━━━━━━━━━┓
    // ┃     Events       ┃
    // ┗━━━━━━━━━━━━━━━━━━┛

    /// @notice Event emitted when a strategy is created.
    /// @param wallet The address of the wallet that created the strategy.
    /// @param strategyId The unique ID of the created strategy.
    /// @param creator The address of the strategy creator.
    /// @param strategy The details of the created strategy.
    event StrategyCreated(address indexed wallet, uint32 strategyId, address creator, Strategy strategy);

    /// @notice Event emitted when a strategy is executed.
    /// @param wallet The address of the wallet executing the strategy.
    /// @param strategyId The unique ID of the strategy being executed.
    event StrategyExecuted(address indexed wallet, uint32 strategyId);

    /// @notice Event emitted when a strategy is deleted.
    /// @param wallet The address of the wallet that deleted the strategy.
    /// @param strategyId The unique ID of the deleted strategy.
    event StrategyDeleted(address indexed wallet, uint32 strategyId);

    /// @notice Event emitted when an automation is created.
    /// @param wallet The address of the wallet creating the automation.
    /// @param automationId The unique ID of the created automation.
    /// @param strategyId The ID of the strategy associated with the automation.
    /// @param condition The condition that must be met for the automation to execute.
    /// @param paymentToken The token used to pay the execution fees.
    /// @param maxFeeAmount The maximum fee the user is willing to pay.
    event AutomationCreated(
        address indexed wallet,
        uint32 automationId,
        uint32 strategyId,
        Condition condition,
        address paymentToken,
        uint256 maxFeeAmount
    );

    /// @notice Event emitted when an automation is deleted.
    /// @param wallet The address of the wallet that deleted the automation.
    /// @param automationId The unique ID of the deleted automation.
    event AutomationDeleted(address indexed wallet, uint32 automationId);

    /// @notice Event emitted when an automation is executed.
    /// @param wallet The address of the wallet executing the automation.
    /// @param automationId The unique ID of the automation being executed.
    /// @param paymentToken The token used to pay for the execution.
    /// @param feeInToken The amount of tokens paid for execution.
    /// @param feeInUSD The value of the fee in USD.
    event AutomationExecuted(
        address indexed wallet, uint32 automationId, address paymentToken, uint256 feeInToken, uint256 feeInUSD
    );

    /// @notice Event emitted when a strategy step is executed.
    /// @param wallet The address of the wallet executing the strategy step.
    /// @param strategyId The unique ID of the strategy being executed.
    /// @param stepId The ID of the step being executed.
    /// @param actions The list of actions executed as part of the step.
    event StrategyStepExecuted(address indexed wallet, uint32 strategyId, uint32 stepId, Action[] actions);

    /// @notice Event emitted when an action is executed.
    /// @param wallet The address of the wallet executing the action.
    /// @param action The details of the action being executed.
    event ActionExecuted(address indexed wallet, Action action);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃     Public Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Creates a new strategy with a given ID, creator address, and strategy steps.
    /// @dev The strategy is stored in a mapping using a bytes32 key generated from the strategy ID and msg.sender.
    /// @param id The unique identifier for the strategy.
    /// @param creator The address of the strategy creator.
    /// @param steps An array of StrategyStep structs defining the sequence of actions and conditions in the strategy.
    function createStrategy(uint32 id, address creator, StrategyStep[] calldata steps) external;

    /// @notice Deletes a strategy associated with the caller's address and the given strategy ID.
    /// @dev Removes the strategy with the specified ID, ensuring the caller is the owner of the strategy.
    /// @param id The unique ID of the strategy to be deleted.
    function deleteStrategy(uint32 id) external;

    /// @notice Executes the strategy associated with the given strategy ID.
    /// @dev Triggers the execution of the strategy identified by the provided ID.
    /// @param id The unique ID of the strategy to be executed.
    function executeStrategy(uint32 id) external;

    /// @notice Creates a new automation linked to an existing strategy with specified execution conditions.
    /// @dev Stores an Action struct that references a strategy and defines a trigger condition for automated execution.
    /// @param id The user-defined identifier for the automation.
    /// @param strategyId The ID of the existing strategy this automation will execute.
    /// @param paymentToken The token address used to pay for execution fees.
    /// @param maxFeeInUSD The maximum fee (denominated in USD) the user is willing to pay for automation execution.
    /// @param condition The trigger condition that must be met to execute the strategy.
    function createAutomation(
        uint32 id,
        uint32 strategyId,
        address paymentToken,
        uint256 maxFeeInUSD,
        Condition calldata condition
    ) external;

    /// @notice Deletes an automation associated with the caller's address and the given automation ID.
    /// @dev Removes the automation with the specified ID, ensuring the caller is the owner of the automation.
    /// @param id The unique ID of the automation to be deleted.
    function deleteAutomation(uint32 id) external;

    /// @notice Executes an existing automation for a specific wallet and distributes fees.
    /// @dev Executes the strategy linked to the given automation ID if the condition is met.
    ///      A portion of the execution fee is sent to the specified beneficiary address.
    /// @param id The ID of the automation to execute.
    /// @param wallet The address for which the automation should be executed (the strategy owner).
    /// @param beneficary The address that will receive a portion of the execution fees as a reward.
    function executeAutomation(uint32 id, address wallet, address beneficary) external;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃     View Functions      ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Retrieves the strategy associated with the given wallet and strategy ID.
    /// @dev Returns the strategy details stored for the specified wallet and strategy ID.
    /// @param wallet The address of the wallet whose strategy is being retrieved.
    /// @param id The unique ID of the strategy to be fetched.
    /// @return The Strategy struct associated with the given wallet and ID.
    function strategy(address wallet, uint32 id) external view returns (Strategy memory);

    /// @notice Retrieves the automation associated with the given wallet and automation ID.
    /// @dev Returns the automation details stored for the specified wallet and automation ID.
    /// @param wallet The address of the wallet whose automation is being retrieved.
    /// @param id The unique ID of the automation to be fetched.
    /// @return The Automation struct associated with the given wallet and ID.
    function automation(address wallet, uint32 id) external view returns (Automation memory);

    /// @notice Computes a unique storage identifier based on the given wallet and ID.
    /// @dev Returns a `bytes32` identifier derived from the wallet address and ID, useful for referencing strategy or automation storage.
    /// @param wallet The address of the wallet to be included in the storage ID calculation.
    /// @param id The unique ID to be included in the storage ID calculation.
    /// @return A unique `bytes32` storage identifier based on the wallet address and ID.
    function getStorageId(address wallet, uint32 id) external pure returns (bytes32);
}
