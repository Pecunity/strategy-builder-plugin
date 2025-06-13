// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {TimeCondition} from "contracts/condition/examples/TimeCondition.sol";
import {ITimeCondition} from "contracts/condition/examples/interfaces/ITimeCondition.sol";

contract TimeConditionTest is Test {
    TimeCondition public timeCondition;
    address public wallet;
    uint32 public conditionId;
    uint256 public FUTURE_TIMESTAMP; // 2 hours in the future
    uint256 public constant MINIMUM_DELTA = 3600; // 1 hour

    event ConditionAdded(uint32 id, address wallet, TimeCondition.Condition condition);
    event ConditionDeleted(uint32 id, address wallet);
    event ConditionUpdated(uint32 id, address wallet, uint256 newExecution);

    function setUp() public {
        timeCondition = new TimeCondition();
        wallet = address(this);
        conditionId = 1;

        FUTURE_TIMESTAMP = block.timestamp + 7200;
    }

    function testAddValidCondition() public {
        TimeCondition.Condition memory condition =
            ITimeCondition.Condition({execution: FUTURE_TIMESTAMP, delta: MINIMUM_DELTA, updateable: true});

        vm.expectEmit(true, true, true, true);
        emit ConditionAdded(conditionId, wallet, condition);

        timeCondition.addCondition(conditionId, condition);

        TimeCondition.Condition memory storedCondition = timeCondition.walletCondition(wallet, conditionId);
        assertEq(storedCondition.execution, FUTURE_TIMESTAMP);
        assertEq(storedCondition.delta, MINIMUM_DELTA);
        assertTrue(storedCondition.updateable);
    }

    function testCannotAddConditionWithPastExecution() public {
        TimeCondition.Condition memory condition =
            ITimeCondition.Condition({execution: block.timestamp - 1, delta: MINIMUM_DELTA, updateable: true});

        vm.expectRevert(ITimeCondition.ExecutionTimeNotValid.selector);
        timeCondition.addCondition(conditionId, condition);
    }

    function testCannotAddConditionWithInvalidDelta() public {
        TimeCondition.Condition memory condition =
            ITimeCondition.Condition({execution: FUTURE_TIMESTAMP, delta: MINIMUM_DELTA - 1, updateable: true});

        vm.expectRevert(ITimeCondition.DeltaNotValid.selector);
        timeCondition.addCondition(conditionId, condition);
    }

    function testDeleteCondition() public {
        TimeCondition.Condition memory condition =
            ITimeCondition.Condition({execution: FUTURE_TIMESTAMP, delta: MINIMUM_DELTA, updateable: true});

        timeCondition.addCondition(conditionId, condition);

        vm.expectEmit(true, true, false, false);
        emit ConditionDeleted(conditionId, wallet);

        timeCondition.deleteCondition(conditionId);

        TimeCondition.Condition memory deletedCondition = timeCondition.walletCondition(wallet, conditionId);
        assertEq(deletedCondition.execution, 0);
    }

    function testUpdateCondition() public {
        TimeCondition.Condition memory condition =
            ITimeCondition.Condition({execution: block.timestamp + 1 hours, delta: MINIMUM_DELTA, updateable: true});

        timeCondition.addCondition(conditionId, condition);

        // Warp to execution time
        vm.warp(block.timestamp + 1 hours);

        vm.expectEmit(true, true, false, true);
        emit ConditionUpdated(conditionId, wallet, condition.execution + condition.delta);

        bool updated = timeCondition.updateCondition(conditionId);
        assertTrue(updated);

        TimeCondition.Condition memory updatedCondition = timeCondition.walletCondition(wallet, conditionId);
        assertEq(updatedCondition.execution, condition.execution + condition.delta);
    }

    function testCannotUpdateBeforeExecutionTime() public {
        TimeCondition.Condition memory condition =
            ITimeCondition.Condition({execution: block.timestamp + 1 hours, delta: MINIMUM_DELTA, updateable: true});

        timeCondition.addCondition(conditionId, condition);

        vm.expectRevert(ITimeCondition.ConditionsIsNotUpdateable.selector);
        timeCondition.updateCondition(conditionId);
    }

    function testCheckCondition() public {
        TimeCondition.Condition memory condition =
            ITimeCondition.Condition({execution: block.timestamp + 1 hours, delta: MINIMUM_DELTA, updateable: true});

        timeCondition.addCondition(conditionId, condition);

        // Before execution time
        assertEq(timeCondition.checkCondition(wallet, conditionId), 0);

        // At execution time
        vm.warp(block.timestamp + 1 hours);
        assertEq(timeCondition.checkCondition(wallet, conditionId), 1);

        // After execution time
        vm.warp(block.timestamp + 2 hours);
        assertEq(timeCondition.checkCondition(wallet, conditionId), 1);
    }

    function testIsUpdateable() public {
        TimeCondition.Condition memory condition =
            ITimeCondition.Condition({execution: FUTURE_TIMESTAMP, delta: MINIMUM_DELTA, updateable: true});

        timeCondition.addCondition(conditionId, condition);
        assertTrue(timeCondition.isUpdateable(wallet, conditionId));

        TimeCondition.Condition memory nonUpdateableCondition =
            ITimeCondition.Condition({execution: FUTURE_TIMESTAMP, delta: MINIMUM_DELTA, updateable: false});

        timeCondition.addCondition(2, nonUpdateableCondition);
        assertFalse(timeCondition.isUpdateable(wallet, 2));
    }
}
