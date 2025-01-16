// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseCondition} from "../../condition/BaseCondition.sol";

contract MockCondition is BaseCondition {
    struct Condition {
        bool result;
        bool active;
    }

    mapping(address wallet => mapping(uint16 => Condition)) private conditions;

    function addCondition(uint16 id, Condition calldata condition) external {
        conditions[msg.sender][id] = condition;
    }

    function _isConditionActive(address, uint16 _id) internal view override returns (bool) {
        return conditions[msg.sender][_id].active;
    }

    function checkCondition(address wallet, uint16 id) public view override returns (uint8) {
        return conditions[wallet][id].result ? 1 : 0;
    }
}
