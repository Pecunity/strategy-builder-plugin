// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockCondition} from "contracts/test/mocks/MockCondition.sol";
import {BaseCondition} from "contracts/condition/BaseCondition.sol";

contract BaseConditionTest is Test {
    MockCondition condition;

    address wallet = makeAddr("wallet");

    function setUp() external {
        condition = new MockCondition();
    }

    /////////////////////////////////
    /////////  addCondition /////////
    /////////////////////////////////

    function test_isConditionActive_ReturnTrueForActiveCondition() external {
        uint32 conditionId = 22;

        vm.prank(wallet);
        MockCondition.Condition memory _condition = MockCondition.Condition({result: true, active: true});
        condition.addCondition(conditionId, _condition);

        assertTrue(condition.isConditionActive(wallet, conditionId));
    }

    function test_isConditionActive_ReturnFalseForInactiveCondition() external {
        uint32 conditionId = 22;

        assertFalse(condition.isConditionActive(wallet, conditionId));
    }

    ////////////////////////////////////
    /////////  updateCondition /////////
    ////////////////////////////////////

    function test_updateCondition_ReturnFalseAsDefault() external {
        uint32 conditionId = 22;
        vm.prank(wallet);
        MockCondition.Condition memory _condition = MockCondition.Condition({result: true, active: true});
        condition.addCondition(conditionId, _condition);

        vm.prank(wallet);
        assertFalse(condition.updateCondition(conditionId));
    }

    ////////////////////////////////////
    /////////  deleteCondition /////////
    ////////////////////////////////////
    function test_deleteCondition_Revert_ConditionIsInUse() external {
        uint32 conditionId = 22;
        vm.prank(wallet);
        MockCondition.Condition memory _condition = MockCondition.Condition({result: true, active: true});
        condition.addCondition(conditionId, _condition);

        vm.prank(wallet);
        condition.addStrategyToCondition(conditionId, 22);

        vm.expectRevert(BaseCondition.ConditionIsInUse.selector);
        vm.prank(wallet);
        condition.deleteCondition(conditionId);
    }

    ///////////////////////////////////
    /////////  checkCondition /////////
    ///////////////////////////////////

    modifier conditionActivated(uint32 _id) {
        vm.assume(_id > 0);

        vm.prank(wallet);
        MockCondition.Condition memory _condition = MockCondition.Condition({result: true, active: true});
        condition.addCondition(_id, _condition);
        _;
    }

    function test_checkCondition(uint32 _id) external conditionActivated(_id) {
        uint8 _result = condition.checkCondition(wallet, _id);

        assert(_result == 1);
    }

    ///////////////////////////////////////////
    /////////  addStrategyToCondition /////////
    ///////////////////////////////////////////

    function test_addStrategyToCondition_Success(uint32 _id) external conditionActivated(_id) {
        vm.assume(_id > 0);

        uint256 strategyNo = 5;
        for (uint256 i = 1; i <= strategyNo; i++) {
            vm.prank(wallet);
            condition.addStrategyToCondition(_id, uint32(i));
        }

        uint32[] memory _strategies = condition.strategies(wallet, _id);

        assertEq(_strategies.length, strategyNo);
    }

    function test_addStrategyToCondition_Revert_ConditionDoesNotExist(uint32 id) external {
        vm.assume(id > 0);

        vm.expectRevert(BaseCondition.ConditionDoesNotExist.selector);
        vm.prank(wallet);
        condition.addStrategyToCondition(id, uint32(22));
    }

    function test_addStrategyToCondition_Revert_ConditionAlreadyInUseOfStrategy(uint32 id)
        external
        conditionActivated(id)
    {
        vm.assume(id > 0);

        uint32 strategyID = 22;
        vm.prank(wallet);
        condition.addStrategyToCondition(id, strategyID);

        vm.expectRevert(BaseCondition.ConditionAlreadyInUseOfStrategy.selector);
        vm.prank(wallet);
        condition.addStrategyToCondition(id, strategyID);
    }

    /////////////////////////////////////////////
    /////////  addAutomationToCondition /////////
    /////////////////////////////////////////////

    function test_addAutomationToCondition_Success(uint32 _id) external conditionActivated(_id) {
        uint256 automationNum = 5;
        for (uint256 i = 1; i <= automationNum; i++) {
            vm.prank(wallet);
            condition.addAutomationToCondition(_id, uint32(i));
        }

        uint32[] memory automations = condition.automations(wallet, _id);

        assertEq(automations.length, automationNum);
    }

    function test_addAutomationToCondition_Revert_ConditionDoesNotExist(uint32 id) external {
        vm.assume(id > 0);

        vm.expectRevert(BaseCondition.ConditionDoesNotExist.selector);
        vm.prank(wallet);
        condition.addAutomationToCondition(id, uint32(22));
    }

    function test_addAutomationToCondition_Revert_ConditionAlreadyInUseOfAutomation(uint32 id)
        external
        conditionActivated(id)
    {
        vm.assume(id > 0);

        uint32 automationID = 22;
        vm.prank(wallet);
        condition.addAutomationToCondition(id, automationID);
        vm.expectRevert(BaseCondition.ConditionAlreadyInUseOfAutomation.selector);
        vm.prank(wallet);
        condition.addAutomationToCondition(id, automationID);
    }

    //////////////////////////////////////////
    ///  removeStrategyFromCondition /////////
    //////////////////////////////////////////

    function test_removeStrategyFromCondition_Success(uint32 _strategyId) external {
        uint32 strategyNum = 5;
        uint32 strategyId = uint32(bound(_strategyId, 1, strategyNum));

        // Add Condition
        uint32 conditionId = 22;
        vm.prank(wallet);
        MockCondition.Condition memory _condition = MockCondition.Condition({result: true, active: true});
        condition.addCondition(conditionId, _condition);

        //Add strategies to condition
        for (uint256 i = 1; i <= strategyNum; i++) {
            vm.prank(wallet);
            condition.addStrategyToCondition(conditionId, uint32(i));
        }

        //Remove specific strategy from condition
        vm.prank(wallet);
        condition.removeStrategyFromCondition(conditionId, strategyId);

        //Assert
        uint32[] memory _strategies = condition.strategies(wallet, conditionId);
        assertEq(_strategies.length, strategyNum - 1);
        assertFalse(condition.conditionInStrategy(wallet, conditionId, strategyId));
    }

    function test_removeStrategyFromCondition_Revert_ConditionNotInUseOfStrategy(uint32 id) external {
        vm.assume(id > 0);

        // Add Condition
        uint32 conditionId = 22;
        vm.prank(wallet);
        MockCondition.Condition memory _condition = MockCondition.Condition({result: true, active: true});
        condition.addCondition(conditionId, _condition);

        vm.expectRevert(BaseCondition.ConditionNotInUseOfStrategy.selector);
        vm.prank(wallet);
        condition.removeStrategyFromCondition(conditionId, id);
    }

    //////////////////////////////////////////
    ///  removeAutomationFromCondition //////
    /////////////////////////////////////////

    function test_removeAutomationFromCondition_Success(uint32 _automationId) external {
        uint32 automationNum = 5;
        uint32 automationId = uint32(bound(_automationId, 1, automationNum));
        // Add Condition
        uint32 conditionId = 22;
        vm.prank(wallet);
        MockCondition.Condition memory _condition = MockCondition.Condition({result: true, active: true});
        condition.addCondition(conditionId, _condition);
        //Add automations to condition
        for (uint256 i = 1; i <= automationNum; i++) {
            vm.prank(wallet);
            condition.addAutomationToCondition(conditionId, uint32(i));
        }

        //Remove specific automation from condition
        vm.prank(wallet);
        condition.removeAutomationFromCondition(conditionId, automationId);

        //Assert
        uint32[] memory _automations = condition.automations(wallet, conditionId);
        assertEq(_automations.length, automationNum - 1);
        assertFalse(condition.conditionInAutomation(wallet, conditionId, automationId));
    }

    function test_removeAutomationFromCondition_Revert_ConditionNotInUseOfAutomation(uint32 id) external {
        vm.assume(id > 0);

        // Add Condition
        uint32 conditionId = 22;
        vm.prank(wallet);
        MockCondition.Condition memory _condition = MockCondition.Condition({result: true, active: true});
        condition.addCondition(conditionId, _condition);
        vm.expectRevert(BaseCondition.ConditionNotInUseOfAutomation.selector);
        vm.prank(wallet);
        condition.removeAutomationFromCondition(conditionId, id);
    }
}
