// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseCondition} from "../../condition/BaseCondition.sol";

contract MockCondition is BaseCondition {
    struct Condition {
        bool result;
        bool active;
        bool updateable;
    }

    mapping(address wallet => mapping(uint32 => Condition)) private conditions;

    function addCondition(uint32 id, Condition calldata condition) external {
        conditions[msg.sender][id] = condition;

        _addCondition(id);
    }

    function checkCondition(address wallet, uint32 id) public view override returns (uint8) {
        return conditions[wallet][id].result ? 1 : 0;
    }

    function isUpdateable(address wallet, uint32 id) public view override returns (bool) {
        return conditions[wallet][id].updateable;
    }

    function updateCondition(uint32 id) public view override conditionExist(id) returns (bool) {
        // Default implementation for updateCondition (override in derived contracts)
        return conditions[msg.sender][id].updateable;
    }
}
