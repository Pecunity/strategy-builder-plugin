// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ICondition} from "../interfaces/ICondition.sol";

error BaseCondition__ConditionDoesNotExist();
error BaseCondition__ConditionAlreadyExist();
error BaseCondition__ConditionIsInUse();

abstract contract BaseCondition is ICondition {
    // Storage for conditions, strategies, and automations
    mapping(address => mapping(uint16 => uint16[])) private conditionStrategies; // (wallet => (id => strategies))
    mapping(address => mapping(uint16 => uint16[])) private conditionAutomations; // (wallet => (id => automations))
    mapping(address => mapping(uint16 => uint16)) private strategyConditionIndex;
    mapping(address => mapping(uint16 => uint16)) private automationConditionIndex;

    modifier conditionExist(uint16 id) {
        if (!_isConditionActive(msg.sender, id)) {
            revert BaseCondition__ConditionDoesNotExist();
        }
        _;
    }

    modifier conditionDoesNotExist(uint16 id) {
        if (_isConditionActive(msg.sender, id)) {
            revert BaseCondition__ConditionAlreadyExist();
        }
        _;
    }

    function checkCondition(address wallet, uint16 id) public view virtual returns (uint8) {
        return 0;
    }

    function isUpdateable(address wallet, uint16 id) public view virtual returns (bool) {
        return false;
    }

    function updateCondition(uint16 id) public virtual returns (bool) {
        // Default implementation for updateCondition (override in derived contracts)
        return false;
    }

    function _isConditionActive(address _wallet, uint16 _id) internal virtual returns (bool) {
        return false;
    }

    function deleteCondition(uint16 id) public virtual {
        if (conditionAutomations[msg.sender][id].length > 0 || conditionStrategies[msg.sender][id].length > 0) {
            revert BaseCondition__ConditionIsInUse();
        }
    }

    function actionValid(address wallet, uint16 id, uint16 action) public view returns (bool) {
        // Validate the action (placeholder implementation)
        return automationConditionIndex[wallet][action] == id;
    }

    function strategyValid(address wallet, uint16 id, uint16 strategy) public view returns (bool) {
        // Validate the strategy (placeholder implementation)
        return strategyConditionIndex[wallet][strategy] == id;
    }

    function addAutomationToCondition(uint16 id, uint16 action) public returns (bool) {
        conditionAutomations[msg.sender][id].push(action);
        automationConditionIndex[msg.sender][action] = uint16(conditionAutomations[msg.sender][id].length - 1);
        return true;
    }

    function addStrategyToCondition(uint16 id, uint16 strategy) public returns (bool) {
        conditionStrategies[msg.sender][id].push(strategy);
        strategyConditionIndex[msg.sender][strategy] = uint16(conditionStrategies[msg.sender][id].length - 1);
        return true;
    }

    function removeAutomationFromCondition(uint16 id, uint16 automation) public returns (bool) {
        uint16[] storage _automations = conditionAutomations[msg.sender][id];

        uint16 _actualAutomationIndex = automationConditionIndex[msg.sender][automation];

        if (_automations[_actualAutomationIndex] != automation) {
            return false;
        }

        uint256 _lastAutomationIndex = _automations.length - 1;

        if (_lastAutomationIndex != _actualAutomationIndex) {
            uint16 _lastAutomationId = _automations[_lastAutomationIndex];
            automationConditionIndex[msg.sender][_lastAutomationId] = _actualAutomationIndex;
            _automations[_actualAutomationIndex] = _lastAutomationId;
        }

        _automations.pop();

        return true;
    }

    function removeStrategyFromCondition(uint16 id, uint16 strategy) public returns (bool) {
        uint16[] storage _strategies = conditionStrategies[msg.sender][id];

        uint16 _actualStrategyIndex = strategyConditionIndex[msg.sender][strategy];

        if (_strategies[_actualStrategyIndex] != strategy) {
            return false;
        }

        uint256 _lastStrategyIndex = _strategies.length - 1;

        if (_lastStrategyIndex != _actualStrategyIndex) {
            uint16 _lastStrategyId = _strategies[_lastStrategyIndex];
            strategyConditionIndex[msg.sender][_lastStrategyId] = _actualStrategyIndex;
            _strategies[_actualStrategyIndex] = _lastStrategyId;
        }

        _strategies.pop();

        return true;
    }

    function strategies(address wallet, uint16 id) external view returns (uint16[] memory) {
        return conditionStrategies[wallet][id];
    }

    function automations(address wallet, uint16 id) external view returns (uint16[] memory) {
        return conditionAutomations[wallet][id];
    }
}
