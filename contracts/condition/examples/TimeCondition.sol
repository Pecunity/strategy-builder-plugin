// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseCondition} from "../BaseCondition.sol";
import {ITimeCondition} from "./interfaces/ITimeCondition.sol";

contract TimeCondition is BaseCondition, ITimeCondition {
    uint256 constant MINIMUM_DELTA = 3600;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        State Variables           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    mapping(address wallet => mapping(uint32 id => Condition condition)) private conditions;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃           Modifiers              ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    modifier validCondition(Condition calldata _condition) {
        if (_condition.execution < block.timestamp) {
            revert ExecutionTimeNotValid();
        }

        if (_condition.delta < MINIMUM_DELTA) {
            revert DeltaNotValid();
        }

        _;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Public Functions           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function addCondition(uint32 _id, Condition calldata _condition) external validCondition(_condition) {
        conditions[msg.sender][_id] = _condition;

        _addCondition(_id); //BaseCondition.sol metho

        emit ConditionAdded(_id, msg.sender, _condition);
    }

    function deleteCondition(uint32 _id) public override {
        super.deleteCondition(_id);
        delete conditions[msg.sender][_id];

        emit ConditionDeleted(_id, msg.sender);
    }

    function updateCondition(uint32 _id) public override returns (bool) {
        Condition memory _condition = conditions[msg.sender][_id];

        if (_condition.execution > block.timestamp) {
            revert ConditionsIsNotUpdateable();
        }

        _condition.execution += _condition.delta;

        conditions[msg.sender][_id] = _condition;

        emit ConditionUpdated(_id, msg.sender, _condition.execution);

        return true;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃         View Functions           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function checkCondition(address _wallet, uint32 _id) public view override returns (uint8) {
        Condition memory _condition = conditions[_wallet][_id];

        if (_condition.execution == 0) {
            return 0;
        }

        if (_condition.execution <= block.timestamp) {
            return 1;
        } else {
            return 0;
        }
    }

    function isUpdateable(address _wallet, uint32 _id) public view override returns (bool) {
        return conditions[_wallet][_id].updateable;
    }

    function walletCondition(address _wallet, uint32 _id) public view returns (Condition memory) {
        return conditions[_wallet][_id];
    }
}
