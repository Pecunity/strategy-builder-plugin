// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IStrategyBuilderPlugin} from "contracts/interfaces/IStrategyBuilderPlugin.sol";

contract StrategyExecutionTest is Test {
    string ARBITRUM_SEPOLIA_FORK = vm.envString("ARBITRUM_SEPOLIA_FORK");
    uint256 baseFork;

    address public constant STRATEGY_BUILDER_PLUGIN = 0x82974170F8D1F1D62fd4d31691C9b22Acf393fCC;

    address public EXECUTOR = makeAddr("executor");

    function setUp() public {
        baseFork = vm.createFork(ARBITRUM_SEPOLIA_FORK);
        vm.selectFork(baseFork);
    }

    function test_automationExecution() external {
        // address wallet = 0xF5C623BC8f11Aa5b8A5bE0A133f16342f82e3D4E;
        // uint32 automationId = 1000703129;

        // // IStrategyBuilderPlugin.Condition memory condition =
        // //     IStrategyBuilderPlugin.Condition({conditionAddress: address(0), id: 0, result0: 0, result1: 0});

        // // IStrategyBuilderPlugin.Action[] memory actions = new IStrategyBuilderPlugin.Action[](1);
        // // actions[0] = IStrategyBuilderPlugin.Action({
        // //     selector: 0x4af8c8ce, // The function selector for the action.
        // //     parameter: "0x000000000000000000000000f5c623bc8f11aa5b8a5be0a133f16342f82e3d4e00000000000000000000000075faf114eafb1bdbe2f0316df893fd58ce46aa4d00000000000000000000000000000000000000000000000000000000000003e8", // The parameters to be passed to the action.
        // //     target: 0x2D5D80c4aF11403715E787fFd9965d195901d55B, // The target address to which the action is directed.
        // //     value: 0, // The value (in wei) to be sent along with the action.
        // //     actionType: IStrategyBuilderPlugin.ActionType.INTERNAL_ACTION // The type of action (external or internal).
        // // });

        // // IStrategyBuilderPlugin.StrategyStep[] memory steps = new IStrategyBuilderPlugin.StrategyStep[](1);
        // // steps[0] = IStrategyBuilderPlugin.StrategyStep({condition: condition, actions: actions});

        // vm.prank(EXECUTOR);
        // // IStrategyBuilderPlugin(STRATEGY_BUILDER_PLUGIN).createStrategy(automationId, wallet, steps);
        // IStrategyBuilderPlugin(STRATEGY_BUILDER_PLUGIN).executeAutomation(automationId, wallet, EXECUTOR);
    }
}
