// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {TimerCondition} from "contracts/condition/examples/TimerCondition.sol";
import {ITimerCondition} from "contracts/condition/examples/interfaces/ITimerCondition.sol";

contract TimerConditionTest is Test {
    TimerCondition timer;

    address wallet = address(1);

    uint32 constant ID = 1;
    uint256 constant DELTA = 3600;

    function setUp() public {
        timer = new TimerCondition();
    }

    function createCondition() internal {
        ITimerCondition.Condition memory condition =
            ITimerCondition.Condition({startTime: 0, delta: DELTA, active: false, updateable: true});

        vm.prank(wallet);
        timer.addCondition(ID, condition);
    }

    /*//////////////////////////////////////////////////////////////
                        ADD CONDITION
    //////////////////////////////////////////////////////////////*/

    function testAddCondition() public {
        createCondition();

        ITimerCondition.Condition memory c = timer.walletCondition(wallet, ID);

        assertEq(c.delta, DELTA);
        assertEq(c.active, false);
    }

    /*//////////////////////////////////////////////////////////////
                        START TIMER
    //////////////////////////////////////////////////////////////*/

    function testStartTimer() public {
        createCondition();

        vm.prank(wallet);
        timer.startTimer(ID);

        ITimerCondition.Condition memory c = timer.walletCondition(wallet, ID);

        assertEq(c.active, true);
        assertEq(c.startTime, block.timestamp);
    }

    function testStartTimerRevertsIfAlreadyActive() public {
        createCondition();

        vm.startPrank(wallet);

        timer.startTimer(ID);

        vm.expectRevert(ITimerCondition.TimerAlreadyActive.selector);
        timer.startTimer(ID);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        CHECK CONDITION
    //////////////////////////////////////////////////////////////*/

    function testCheckConditionBeforeFinished() public {
        createCondition();

        vm.prank(wallet);
        timer.startTimer(ID);

        uint8 result = timer.checkCondition(wallet, ID);

        assertEq(result, 0);
    }

    function testCheckConditionAfterFinished() public {
        createCondition();

        vm.prank(wallet);
        timer.startTimer(ID);

        vm.warp(block.timestamp + DELTA);

        uint8 result = timer.checkCondition(wallet, ID);

        assertEq(result, 1);
    }

    /*//////////////////////////////////////////////////////////////
                        UPDATE CONDITION
    //////////////////////////////////////////////////////////////*/

    function testUpdateConditionRevertsIfNotFinished() public {
        createCondition();

        vm.prank(wallet);
        timer.startTimer(ID);

        vm.prank(wallet);

        vm.expectRevert(ITimerCondition.TimerNotFinished.selector);
        timer.updateCondition(ID);
    }

    function testUpdateConditionSuccess() public {
        createCondition();

        vm.startPrank(wallet);

        timer.startTimer(ID);

        vm.warp(block.timestamp + DELTA);

        bool success = timer.updateCondition(ID);

        assertTrue(success);

        ITimerCondition.Condition memory c = timer.walletCondition(wallet, ID);

        assertEq(c.active, false);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        DELETE CONDITION
    //////////////////////////////////////////////////////////////*/

    function testDeleteCondition() public {
        createCondition();

        vm.prank(wallet);
        timer.deleteCondition(ID);

        ITimerCondition.Condition memory c = timer.walletCondition(wallet, ID);

        assertEq(c.delta, 0);
        assertEq(c.startTime, 0);
        assertEq(c.active, false);
    }
}
