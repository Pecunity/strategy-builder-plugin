// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IStrategyBuilderPlugin} from "../../src/interfaces/IStrategyBuilderPlugin.sol";

contract StrategyExecutionTest is Test {
    string ARBITRUM_SEPOLIA_FORK = vm.envString("ARBITRUM_SEPOLIA_FORK");
    uint256 baseFork;

    address public constant STRATEGY_BUILDER_PLUGIN = 0x4e95E72Be46185C215cb1ba910Ba170e13f9562B;

    address public EXECUTOR = makeAddr("executor");

    function setUp() public {
        baseFork = vm.createFork(ARBITRUM_SEPOLIA_FORK);
        vm.selectFork(baseFork);
    }

    function test_automationExecution() external {
        // address wallet = 0xA286BA348C6b051c721723a1fAC7391272bE867a;
        // uint32 automationId = 3033276506;

        // // IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
        // //     conditionAddress: 0x611cff612D70088428E37D87a1F5BD8Fbb61233A,
        // //     id: automationId,
        // //     result0: 0,
        // //     result1: 0
        // // });

        // vm.prank(EXECUTOR);
        // IStrategyBuilderPlugin(STRATEGY_BUILDER_PLUGIN).executeAutomation(automationId, wallet, EXECUTOR);
    }
}
