// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseCondition} from "../../condition/BaseCondition.sol";

contract MockCondition is BaseCondition {
    struct Condition {
        bool result;
        bool active;
    }

    mapping(address wallet => mapping(uint32 => Condition)) private conditions;

    function addCondition(uint32 id, Condition calldata condition) external {
        conditions[msg.sender][id] = condition;

        _addCondition(id);
    }

    function checkCondition(address wallet, uint32 id) public view override returns (uint8) {
        return conditions[wallet][id].result ? 1 : 0;
    }
}
