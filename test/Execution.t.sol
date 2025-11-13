// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IStrategyBuilderModule} from "../../contracts/interfaces/IStrategyBuilderModule.sol";
import {IAction} from "../../contracts/interfaces/IAction.sol";
import {ITokenGetter} from "../../contracts/interfaces/ITokenGetter.sol";

contract StrategyExecutionTest is Test {
    string SEPOLIA_FORK = vm.envString("SEPOLIA_FORK");
    uint256 baseFork;

    address public constant STRATEGY_BUILDER_PLUGIN = 0xD4FC1c1fF44bc99b13d02356d8257bb17b5d43dA;
    address public constant AAVE_V3_Actions = 0x15E4Fd9325b73a09Ef30966DB0F4A4B863aEEf97;

    address public EXECUTOR = makeAddr("executor");

    function setUp() public {
        baseFork = vm.createFork(SEPOLIA_FORK);
        vm.selectFork(baseFork);
    }

    function test_automationExecution() external {
        address wallet = 0x25cc8eE8efDFd50D063A717363D099E92EBc56b7;
        uint32 strategyID = 3155266195;

        address USDC = 0x29f2D40B0605204364af54EC677bD022dA425d03;

        // address owner = 0x582B58B38118D905a681E72f71Af420d3BFE30bc;

        uint256 amount = 0.001 ether;

        IStrategyBuilderModule.StrategyStep[] memory steps = new IStrategyBuilderModule.StrategyStep[](1);

        IStrategyBuilderModule.Action[] memory actions = new IStrategyBuilderModule.Action[](2);
        actions[0] = IStrategyBuilderModule.Action({
            selector: IAaveV3Actions.supplyETH.selector,
            parameter: abi.encode(wallet, amount),
            value: 0,
            target: AAVE_V3_Actions,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: new IStrategyBuilderModule.ContextKey[](0), // Empty array
            output: IStrategyBuilderModule.ContextKey({ // Empty struct
                key: "",
                parameterReplacement: IStrategyBuilderModule.Parameter({
                    offset: 0,
                    length: 0,
                    paramType: IStrategyBuilderModule.ParamType.UINT256
                })
            }),
            result: 0
        });

        actions[1] = IStrategyBuilderModule.Action({
            selector: IAaveV3Actions.borrowToHealthFactor.selector,
            parameter: abi.encode(wallet, USDC, 1.21 ether, 2),
            value: 0,
            target: AAVE_V3_Actions,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: new IStrategyBuilderModule.ContextKey[](0), // Empty array
            output: IStrategyBuilderModule.ContextKey({ // Empty struct
                key: "",
                parameterReplacement: IStrategyBuilderModule.Parameter({
                    offset: 0,
                    length: 0,
                    paramType: IStrategyBuilderModule.ParamType.UINT256
                })
            }),
            result: 0
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
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).createStrategy(strategyID, address(0), steps);

        vm.prank(wallet);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).executeStrategy(strategyID);
    }
}

interface IAaveV3Actions is IAction {
    // ┏━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Errors       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━┛

    error ZeroAmountNotValid();
    error HealthFactorNotValid();
    error InvalidTokenGetterID();
    error InvalidPercentage();

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function supply(address wallet, address asset, uint256 amount)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function supplyETH(address wallet, uint256 amount) external view returns (PluginExecution[] memory, bytes memory);

    function withdraw(address wallet, address asset, uint256 amount)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function withdrawETH(address wallet, uint256 amount)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function borrow(address wallet, address asset, uint256 amount, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function borrowETH(address wallet, uint256 amount, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function repay(address wallet, address asset, uint256 amount, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function repayETH(address wallet, uint256 amount, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function supplyPercentageOfBalance(address wallet, address asset, uint256 percentage)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function supplyPercentageOfBalanceETH(address wallet, uint256 percentage)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function changeSupplyToHealthFactorETH(address wallet, uint256 targetHealthFactor)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function changeSupplyToHealthFactor(address wallet, address asset, uint256 targetHealthFactor)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function borrowPercentageOfAvailable(address wallet, address asset, uint256 percentage, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function borrowPercentageOfAvailableETH(address wallet, uint256 percentage, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function repayPercentageOfDebt(address wallet, address asset, uint256 percentage, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function repayPercentageOfDebtETH(address wallet, uint256 percentage, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function repayPercentageOfBalance(address wallet, address asset, uint256 percentage, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function repayPercentageOfBalanceETH(address wallet, uint256 percentage, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function repayToHealthFactor(address wallet, address asset, uint256 targetHealthFactor, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function repayToHealthFactorETH(address wallet, uint256 targetHealthFactor, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function borrowToHealthFactor(address wallet, address asset, uint256 targetHealthFactor, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function borrowToHealthFactorETH(address wallet, uint256 targetHealthFactor, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function changeDebtToHealthFactor(
        address wallet,
        address asset,
        uint256 targetHealthFactor,
        uint256 interestRateMode
    ) external view returns (PluginExecution[] memory, bytes memory);

    function changeDebtToHealthFactorETH(address wallet, uint256 targetHealthFactor, uint256 interestRateMode)
        external
        view
        returns (PluginExecution[] memory, bytes memory);

    function calculateBorrowAmount(address wallet, address asset, uint256 percentage) external view returns (uint256);

    function calculateDeltaCol(address wallet, address asset, uint256 targetHealthFactor)
        external
        view
        returns (uint256 deltaCol, bool isWithdraw);

    function calculateDeltaDebt(address wallet, address asset, uint256 targetHealthFactor)
        external
        view
        returns (uint256 deltaDebt, bool isRepay);
}
