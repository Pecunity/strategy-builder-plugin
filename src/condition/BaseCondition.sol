// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ICondition} from "../interfaces/ICondition.sol";

error BaseCondition__ConditionDoesNotExist();
error BaseCondition__ConditionAlreadyExist();
error BaseCondition__ConditionIsInUse();

abstract contract BaseCondition is ICondition {
    // Storage for conditions, strategies, and automations
    mapping(address => mapping(uint32 => uint32[])) private conditionStrategies; // (wallet => (id => strategies))
    mapping(address => mapping(uint32 => uint32[])) private conditionAutomations; // (wallet => (id => automations))
    mapping(address => mapping(uint32 => uint32)) private strategyConditionIndex;
    mapping(address => mapping(uint32 => uint32)) private automationConditionIndex;

    modifier conditionExist(uint32 id) {
        if (!_isConditionActive(msg.sender, id)) {
            revert BaseCondition__ConditionDoesNotExist();
        }
        _;
    }

    modifier conditionDoesNotExist(uint32 id) {
        if (_isConditionActive(msg.sender, id)) {
            revert BaseCondition__ConditionAlreadyExist();
        }
        _;
    }

    function checkCondition(address, uint32) public view virtual returns (uint8) {
        return 0;
    }

    function isUpdateable(address, uint32) public view virtual returns (bool) {
        return false;
    }

    function updateCondition(uint32) public virtual returns (bool) {
        // Default implementation for updateCondition (override in derived contracts)
        return false;
    }

    function conditionActive(address _wallet, uint32 _id) external view returns (bool) {
        return _isConditionActive(_wallet, _id);
    }

    function _isConditionActive(address, uint32) internal view virtual returns (bool) {
        return false;
    }

    function deleteCondition(uint32 _id) public virtual {
        if (conditionAutomations[msg.sender][_id].length > 0 || conditionStrategies[msg.sender][_id].length > 0) {
            revert BaseCondition__ConditionIsInUse();
        }
    }

    function actionValid(address wallet, uint32 id, uint32 action) public view returns (bool) {
        // Validate the action (placeholder implementation)
        return automationConditionIndex[wallet][action] == id;
    }

    function strategyValid(address wallet, uint32 id, uint32 strategy) public view returns (bool) {
        // Validate the strategy (placeholder implementation)
        return strategyConditionIndex[wallet][strategy] == id;
    }

    function addAutomationToCondition(uint32 id, uint32 action) public returns (bool) {
        conditionAutomations[msg.sender][id].push(action);
        automationConditionIndex[msg.sender][action] = uint32(conditionAutomations[msg.sender][id].length - 1);
        return true;
    }

    function addStrategyToCondition(uint32 id, uint32 strategy) public returns (bool) {
        conditionStrategies[msg.sender][id].push(strategy);
        strategyConditionIndex[msg.sender][strategy] = uint32(conditionStrategies[msg.sender][id].length - 1);
        return true;
    }

    function removeAutomationFromCondition(uint32 id, uint32 automation) public returns (bool) {
        uint32[] storage _automations = conditionAutomations[msg.sender][id];

        uint32 _actualAutomationIndex = automationConditionIndex[msg.sender][automation];

        if (_automations[_actualAutomationIndex] != automation) {
            return false;
        }

        uint256 _lastAutomationIndex = _automations.length - 1;

        if (_lastAutomationIndex != _actualAutomationIndex) {
            uint32 _lastAutomationId = _automations[_lastAutomationIndex];
            automationConditionIndex[msg.sender][_lastAutomationId] = _actualAutomationIndex;
            _automations[_actualAutomationIndex] = _lastAutomationId;
        }

        _automations.pop();

        return true;
    }

    function removeStrategyFromCondition(uint32 id, uint32 strategy) public returns (bool) {
        uint32[] storage _strategies = conditionStrategies[msg.sender][id];

        uint32 _actualStrategyIndex = strategyConditionIndex[msg.sender][strategy];

        if (_strategies[_actualStrategyIndex] != strategy) {
            return false;
        }

        uint256 _lastStrategyIndex = _strategies.length - 1;

        if (_lastStrategyIndex != _actualStrategyIndex) {
            uint32 _lastStrategyId = _strategies[_lastStrategyIndex];
            strategyConditionIndex[msg.sender][_lastStrategyId] = _actualStrategyIndex;
            _strategies[_actualStrategyIndex] = _lastStrategyId;
        }

        _strategies.pop();

        return true;
    }

    function strategies(address wallet, uint32 id) external view returns (uint32[] memory) {
        return conditionStrategies[wallet][id];
    }

    function automations(address wallet, uint32 id) external view returns (uint32[] memory) {
        return conditionAutomations[wallet][id];
    }
}
