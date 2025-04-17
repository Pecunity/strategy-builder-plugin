// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ICondition} from "../interfaces/ICondition.sol";

/// @title BaseCondition
/// @notice Abstract contract to manage condition lifecycle, automations, and strategy associations.
/// @dev This contract must be inherited by a concrete condition contract.
abstract contract BaseCondition is ICondition {
    // ┏━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Errors       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━┛
    error InvalidID();
    error ConditionDoesNotExist();
    error ConditionAlreadyExist();
    error ConditionIsInUse();
    error ConditionAlreadyInUseOfStrategy();
    error ConditionNotInUseOfStrategy();
    error ConditionAlreadyInUseOfAutomation();
    error ConditionNotInUseOfAutomation();

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       StateVariable       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Mapping of strategies associated with conditions per wallet.
    mapping(address wallet => mapping(uint32 id => uint32[] strategies)) private conditionStrategies;

    /// @notice Mapping of automations associated with conditions per wallet.
    mapping(address wallet => mapping(uint32 id => uint32[] automations)) private conditionAutomations;

    /// @notice Index tracker for each strategy within a condition.
    mapping(address wallet => mapping(uint32 id => mapping(uint32 strategyId => uint32 index))) private strategyIndexes;

    /// @notice Index tracker for each automation within a condition.
    mapping(address wallet => mapping(uint32 id => mapping(uint32 automationId => uint32 index))) private
        automationIndexes;

    /// @notice Tracks whether a condition is active.
    mapping(address wallet => mapping(uint32 id => bool active)) private conditionActive;

    // ┏━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Events       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━┛
    event ConditionDeleted(address indexed wallet, uint32 indexed id);
    event StrategyAdded(address indexed wallet, uint32 indexed id, uint32 strategy);
    event StrategyRemoved(address indexed wallet, uint32 indexed id, uint32 strategy);
    event AutomationAdded(address indexed wallet, uint32 indexed id, uint32 automation);
    event AutomationRemoved(address indexed wallet, uint32 indexed id, uint32 automation);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Modifier            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    modifier conditionExist(uint32 id) {
        if (!conditionActive[msg.sender][id]) {
            revert ConditionDoesNotExist();
        }
        _;
    }

    modifier conditionDoesNotExist(uint32 id) {
        if (conditionActive[msg.sender][id]) {
            revert ConditionAlreadyExist();
        }
        _;
    }

    modifier nonZeroID(uint32 id) {
        if (id == 0) {
            revert InvalidID();
        }
        _;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc ICondition
    function updateCondition(uint32 id) public virtual conditionExist(id) returns (bool) {
        // Default implementation for updateCondition (override in derived contracts)
        return false;
    }

    /// @inheritdoc ICondition
    function deleteCondition(uint32 id) public virtual conditionExist(id) {
        if (conditionAutomations[msg.sender][id].length > 0 || conditionStrategies[msg.sender][id].length > 0) {
            revert ConditionIsInUse();
        }

        conditionActive[msg.sender][id] = false;

        emit ConditionDeleted(msg.sender, id);
    }

    /// @inheritdoc ICondition
    function addAutomationToCondition(uint32 id, uint32 automation)
        public
        conditionExist(id)
        nonZeroID(automation)
        returns (bool)
    {
        if (conditionInAutomation(msg.sender, id, automation)) {
            revert ConditionAlreadyInUseOfAutomation();
        }

        conditionAutomations[msg.sender][id].push(automation);
        automationIndexes[msg.sender][id][automation] = uint32(conditionAutomations[msg.sender][id].length - 1);

        emit AutomationAdded(msg.sender, id, automation);

        return true;
    }

    /// @inheritdoc ICondition
    function addStrategyToCondition(uint32 id, uint32 strategy)
        public
        conditionExist(id)
        nonZeroID(strategy)
        returns (bool)
    {
        if (conditionInStrategy(msg.sender, id, strategy)) {
            revert ConditionAlreadyInUseOfStrategy();
        }

        conditionStrategies[msg.sender][id].push(strategy);
        strategyIndexes[msg.sender][id][strategy] = uint32(conditionStrategies[msg.sender][id].length - 1);

        emit StrategyAdded(msg.sender, id, strategy);

        return true;
    }

    /// @inheritdoc ICondition
    function removeAutomationFromCondition(uint32 id, uint32 automation) public conditionExist(id) returns (bool) {
        if (!conditionInAutomation(msg.sender, id, automation)) {
            revert ConditionNotInUseOfAutomation();
        }

        uint32[] storage _automations = conditionAutomations[msg.sender][id];

        uint32 _actualAutomationIndex = automationIndexes[msg.sender][id][automation];

        uint256 _lastAutomationIndex = _automations.length - 1;

        if (_lastAutomationIndex != _actualAutomationIndex) {
            uint32 _lastAutomationId = _automations[_lastAutomationIndex];
            automationIndexes[msg.sender][id][_lastAutomationId] = _actualAutomationIndex;
            _automations[_actualAutomationIndex] = _lastAutomationId;
        }

        _automations.pop();

        delete automationIndexes[msg.sender][id][automation];

        emit AutomationRemoved(msg.sender, id, automation);

        return true;
    }

    /// @inheritdoc ICondition
    function removeStrategyFromCondition(uint32 id, uint32 strategy) public conditionExist(id) returns (bool) {
        if (!conditionInStrategy(msg.sender, id, strategy)) {
            revert ConditionNotInUseOfStrategy();
        }

        uint32[] storage _strategies = conditionStrategies[msg.sender][id];

        uint32 _actualStrategyIndex = strategyIndexes[msg.sender][id][strategy];

        uint256 _lastStrategyIndex = _strategies.length - 1;

        if (_lastStrategyIndex != _actualStrategyIndex) {
            uint32 _lastStrategyId = _strategies[_lastStrategyIndex];
            strategyIndexes[msg.sender][id][_lastStrategyId] = _actualStrategyIndex;
            _strategies[_actualStrategyIndex] = _lastStrategyId;
        }

        _strategies.pop();

        delete strategyIndexes[msg.sender][id][strategy];

        emit StrategyRemoved(msg.sender, id, strategy);

        return true;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Internal functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _addCondition(uint32 id) internal conditionDoesNotExist(id) nonZeroID(id) {
        conditionActive[msg.sender][id] = true;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    External View Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc ICondition
    function isConditionActive(address wallet, uint32 id) external view returns (bool) {
        return conditionActive[wallet][id];
    }

    /// @inheritdoc ICondition
    function strategies(address wallet, uint32 id) external view returns (uint32[] memory) {
        return conditionStrategies[wallet][id];
    }

    /// @inheritdoc ICondition
    function automations(address wallet, uint32 id) external view returns (uint32[] memory) {
        return conditionAutomations[wallet][id];
    }

    /// @inheritdoc ICondition
    function checkCondition(address, uint32) public view virtual returns (uint8) {
        return 0;
    }

    /// @inheritdoc ICondition
    function isUpdateable(address, uint32) public view virtual returns (bool) {
        return false;
    }

    /// @inheritdoc ICondition
    function conditionInAutomation(address wallet, uint32 id, uint32 automationId) public view returns (bool) {
        uint256 automationIndex = automationIndexes[wallet][id][automationId];

        if (conditionAutomations[wallet][id].length == 0 || automationIndex >= conditionAutomations[wallet][id].length)
        {
            return false;
        }

        return conditionAutomations[wallet][id][automationIndex] == automationId;
    }

    /// @inheritdoc ICondition
    function conditionInStrategy(address wallet, uint32 id, uint32 strategyId) public view returns (bool) {
        uint256 strategyIndex = strategyIndexes[wallet][id][strategyId];

        if (conditionStrategies[wallet][id].length == 0 || strategyIndex >= conditionStrategies[wallet][id].length) {
            return false;
        }

        return conditionStrategies[wallet][id][strategyIndex] == strategyId;
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(ICondition).interfaceId;
    }
}
