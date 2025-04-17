// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ICondition is IERC165 {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Updates a condition. To be overridden in derived contracts.
    /// @param id The condition ID.
    /// @return success Whether the update was performed.
    function updateCondition(uint32 id) external returns (bool);

    /// @notice Deletes a condition if it's not in use.
    /// @param id The condition ID to delete.
    function deleteCondition(uint32 id) external;

    /// @notice Associates an automation with a condition.
    /// @param id The condition ID.
    /// @param automation The automation ID.
    /// @return success Whether the automation was added.
    function addAutomationToCondition(uint32 id, uint32 automation) external returns (bool);

    /// @notice Associates a strategy with a condition.
    /// @param id The condition ID.
    /// @param strategy The strategy ID.
    /// @return success Whether the strategy was added.
    function addStrategyToCondition(uint32 id, uint32 strategy) external returns (bool);

    /// @notice Removes an automation from a condition.
    /// @param id The condition ID.
    /// @param automation The automation ID.
    /// @return success Whether the automation was removed.
    function removeAutomationFromCondition(uint32 id, uint32 automation) external returns (bool);

    /// @notice Removes a strategy from a condition.
    /// @param id The condition ID.
    /// @param strategy The strategy ID.
    /// @return success Whether the strategy was removed.
    function removeStrategyFromCondition(uint32 id, uint32 strategy) external returns (bool);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    External View Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Returns whether a condition is active.
    /// @param wallet The wallet address.
    /// @param id The condition ID.
    /// @return active Whether the condition is active.
    function isConditionActive(address wallet, uint32 id) external view returns (bool);

    /// @notice Gets strategies associated with a condition.
    /// @param wallet The wallet address.
    /// @param id The condition ID.
    /// @return strategyList List of strategy IDs.
    function strategies(address wallet, uint32 id) external view returns (uint32[] memory);

    /// @notice Gets automations associated with a condition.
    /// @param wallet The wallet address.
    /// @param id The condition ID.
    /// @return automationList List of automation IDs.
    function automations(address wallet, uint32 id) external view returns (uint32[] memory);

    /// @notice Checks the condition logic. Meant to be overridden.
    /// @param wallet Wallet that owns the condition.
    /// @param id Condition ID.
    /// @return status The result of the condition check.
    function checkCondition(address wallet, uint32 id) external view returns (uint8);

    /// @notice Indicates whether the condition is updatable. Meant to be overridden.
    /// @param wallet Wallet address.
    /// @param id Condition ID.
    /// @return updateable True if the condition is updatable.
    function isUpdateable(address wallet, uint32 id) external view returns (bool);

    /// @notice Checks whether a condition includes a specific automation.
    /// @param wallet Wallet address.
    /// @param id Condition ID.
    /// @param automationId Automation ID.
    /// @return inCondition True if the condition includes the automation.
    function conditionInAutomation(address wallet, uint32 id, uint32 automationId) external view returns (bool);

    /// @notice Checks whether a condition includes a specific strategy.
    /// @param wallet Wallet address.
    /// @param id Condition ID.
    /// @param strategyId Strategy ID.
    /// @return inCondition True if the condition includes the strategy.
    function conditionInStrategy(address wallet, uint32 id, uint32 strategyId) external view returns (bool);
}
