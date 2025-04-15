// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseCondition} from "./BaseCondition.sol";

error TimeCondition__ExecutionTimeNotValid();
error TimeCondition__DeltaNotValid();
error TimeCondition__ConditionsIsNotUpdateable();

contract TimeCondition is BaseCondition {
    uint256 constant MINIMUM_DELTA = 3600;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃           Structs                ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    struct Condition {
        uint256 execution;
        uint256 delta;
        bool updateable;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        State Variables           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    mapping(address wallet => mapping(uint32 id => Condition condition)) private conditions;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃           Modifiers              ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    modifier validCondition(Condition calldata _condition) {
        if (_condition.execution < block.timestamp) {
            revert TimeCondition__ExecutionTimeNotValid();
        }

        if (_condition.delta < MINIMUM_DELTA) {
            revert TimeCondition__DeltaNotValid();
        }

        _;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃            Events                ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    event ConditionAdded(uint32 id, address wallet, Condition condition);
    event ConditionDeleted(uint32 id, address wallet);
    event ConditionUpdated(uint32 id, address wallet, uint256 newExecution);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Public Functions           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function addCondition(uint32 _id, Condition calldata _condition)
        external
        conditionDoesNotExist(_id)
        validCondition(_condition)
    {
        conditions[msg.sender][_id] = _condition;

        emit ConditionAdded(_id, msg.sender, _condition);
    }

    function deleteCondition(uint32 _id) public override conditionExist(_id) {
        super.deleteCondition(_id);
        delete conditions[msg.sender][_id];

        emit ConditionDeleted(_id, msg.sender);
    }

    function updateCondition(uint32 _id) public override conditionExist(_id) returns (bool) {
        Condition memory _condition = conditions[msg.sender][_id];

        if (_condition.execution > block.timestamp) {
            revert TimeCondition__ConditionsIsNotUpdateable();
        }

        _condition.execution += _condition.delta;

        conditions[msg.sender][_id] = _condition;

        emit ConditionUpdated(_id, msg.sender, _condition.execution);

        return true;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Internal Functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _isConditionActive(address _wallet, uint32 _id) internal view override returns (bool) {
        return conditions[_wallet][_id].execution != 0;
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
