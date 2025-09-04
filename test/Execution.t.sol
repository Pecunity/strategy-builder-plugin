// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IStrategyBuilderModule} from "../../contracts/interfaces/IStrategyBuilderModule.sol";

contract StrategyExecutionTest is Test {
    string ARBITRUM_SEPOLIA_FORK = vm.envString("ARBITRUM_SEPOLIA_FORK");
    uint256 baseFork;

    address public constant STRATEGY_BUILDER_PLUGIN = 0xd34861a46cA9EBe8D9aE65148b03Da89f6B3444c;

    address public EXECUTOR = makeAddr("executor");

    function setUp() public {
        baseFork = vm.createFork(ARBITRUM_SEPOLIA_FORK);
        vm.selectFork(baseFork);
    }

    function test_automationExecution() external {
        address wallet = 0xF5C623BC8f11Aa5b8A5bE0A133f16342f82e3D4E;
        uint32 automationId = 4074435609;

        address owner = 0x582B58B38118D905a681E72f71Af420d3BFE30bc;

        IStrategyBuilderModule.StrategyStep[] memory steps = new IStrategyBuilderModule.StrategyStep[](1);

        IStrategyBuilderModule.Action[] memory actions = new IStrategyBuilderModule.Action[](1);
        actions[0] = IStrategyBuilderModule.Action({
            selector: 0x5770aafe,
            parameter: "0x000000000000000000000000f5c623bc8f11aa5b8a5be0a133f16342f82e3d4e00000000000000000000000000000000000000000000000000005af3107a4000",
            value: 0,
            target: 0xFE24739Eef819c93dDdd838eE7CAf6521433eE73,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION
        });

        steps[0] = IStrategyBuilderModule.StrategyStep({
            condition: IStrategyBuilderModule.Condition({conditionAddress: address(0), id: 0, result0: 0, result1: 0}),
            actions: actions
        });

        // IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
        //     conditionAddress: 0x611cff612D70088428E37D87a1F5BD8Fbb61233A,
        //     id: automationId,
        //     result0: 0,
        //     result1: 0
        // });

        vm.prank(wallet);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).createStrategy(automationId, address(0), steps);
    }
}
