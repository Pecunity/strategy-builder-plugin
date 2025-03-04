// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MockCondition} from "../src/test/mocks/MockCondition.sol";

contract BaseConditionTest is Test {
    MockCondition condition;

    address wallet = makeAddr("wallet");

    function setUp() external {
        condition = new MockCondition();
    }

    ///////////////////////////////////
    /////////  checkCondition /////////
    ///////////////////////////////////

    modifier conditionActivated(uint32 _id) {
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
        uint256 strategyNo = 5;
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(wallet);
            condition.addStrategyToCondition(_id, uint32(i));
        }

        uint32[] memory _strategies = condition.strategies(wallet, _id);

        assertEq(_strategies.length, strategyNo);
    }
}
