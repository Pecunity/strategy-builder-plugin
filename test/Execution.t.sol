// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IStrategyBuilderModule} from "../../contracts/interfaces/IStrategyBuilderModule.sol";
import {IAction} from "../../contracts/interfaces/IAction.sol";
import {ITokenGetter} from "../../contracts/interfaces/ITokenGetter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TimeCondition} from "../../contracts/condition/examples/TimeCondition.sol";
import {ITimeCondition} from "../../contracts/condition/examples/interfaces/ITimeCondition.sol";
import {CoinOrERC20BalanceCondition} from "../../contracts/condition/examples/CoinOrERC20BalanceCondition.sol";
import {ICoinOrERC20BalanceCondition} from
    "../../contracts/condition/examples/interfaces/ICoinOrERC20BalanceCondition.sol";
import {MathAction} from "../../contracts/action/MathAction.sol";
import {ICondition} from "../../contracts/interfaces/ICondition.sol";

contract StrategyExecutionTest is Test {
    string BNB_FORK = vm.envString("BNB_FORK");
    uint256 baseFork;

    address wallet = 0x25cc8eE8efDFd50D063A717363D099E92EBc56b7;

    address public constant STRATEGY_BUILDER_PLUGIN = 0x00FB707CCc491DB9b5bf556EeeD00CB83eD10E05;
    address public constant AAVE_V3_Actions = 0x8C262ec2db34a6CdA55ba9aDe792225191e0754C;
    address public constant PANCAKE_SWAP_V3_ONE_SIDED_LP_ACTIONS = 0x76F20A078392bF5A8e68d4d3b6Dcede4C554c9B0;
    address public constant PANCAKE_SWAP_V3_LP_ACTIONS = 0xE234Df5EfA5c5B1C04efc4F35d86F89B9A427509;
    address public constant PANCAKE_SWAP_V3_SWAP_ACTIONS = 0x51ba132B96607A4BfdCd212772aC2Ab3f5E1D851;
    address public constant TIME_CONDITION = 0x43FB488Eaa15deE312283d27d4cf89Cd26d01d0d;
    address public constant MATH_ACTION = 0x4F9CC7B7fc7b71BE12ae8A9441D0d673d2b92e08;
    address public constant ERC20_TOKEN_BALANCE_CONDITION = 0x9C736C92997F7C9d67c2CcDa6Ba24281498B8c64;
    address public constant PANCAKE_SWAP_V3_POSITION_RANGE_CHECKER = 0xe16875df74A38dB4d2A329589d18B7ccF0336F34;

    address public constant PANCAKE_SWAP_V3_ROUTER = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;
    address public constant PANCAKE_SWAP_V3_POSITION_MANAGER = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;

    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public constant aBNB = 0x9B00a09492a626678E5A3009982191586C444Df9;
    address public constant wBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant debtUSDT = 0xF8bb2Be50647447Fb355e3a77b81be4db64107cd;

    //setUp

    bytes32 public constant CONTEXT_ID = 0x8b4a89e6f417d4f7d47e91bde9f5e3e65d73013e0b77b4acdb8b12947a0cd82c;
    uint32 public constant STRATEGY_ID = 3155266195;

    //1.1 Supply wBNB
    uint256 constant AMOUNT = 2 ether;
    bytes32 constant SUPPLY_AMOUNT_KEY = bytes32(bytes("supply_amount"));

    //1.2 Borrow USDT to HealthFactor
    uint256 constant HEALTH_FACTOR = 1.21 ether;
    uint256 constant INTEREST_RATE_MODE = 2;
    bytes32 constant BORROW_AMOUNT_KEY = bytes32(bytes("borrow_amount"));

    //1.3 Provide OneSided LP on pancakeswap
    address constant PANCAKE_SWAP_POOL = 0x172fcD41E0913e95784454622d1c3724f546f849;
    uint24 constant POOL_FEE = 100;
    IUniswapV3OneSidedLPActions.AddLiquidityOneSidedRangeParams LP_PARAMS = IUniswapV3OneSidedLPActions
        .AddLiquidityOneSidedRangeParams({tokenIn: USDT, token0: USDT, token1: wBNB, fee: POOL_FEE, recipient: wallet});
    uint24 constant PERCENTAGE = 250;
    bytes32 constant LP_POSITION_KEY = bytes32(bytes("lp_position"));

    //2 Inteval Strategy
    uint32 public constant STRATEGY_ID_INTERVAL = 3155266196;
    uint32 public constant CONDITION_ID_INTERVAL = 3155266196;
    uint256 public constant DELTA_INTERVAL = 60 * 60 * 24;

    //2.1 Collect LP Rewards
    INonfungiblePositionManager.CollectParams COLLECT_PARAMS = INonfungiblePositionManager.CollectParams({
        tokenId: 0,
        recipient: wallet,
        amount0Max: type(uint128).max,
        amount1Max: type(uint128).max
    });

    //2.2 Supply wBNB to Aave and repay USDT to Aave
    uint256 constant PERCENTAGE_AAVE = 10_000;

    //3 Price Range Strategy
    uint256 constant PERCENTAGE_LP = 1000;
    uint32 public constant STRATEGY_ID_LOWER_TICK = 3155266197;
    uint32 public constant CONDITION_ID_LOWER_TICK = 3155266197;
    bytes32 constant REMOVE_LP_AMOUNT_KEY = bytes32(bytes("remove_lp_amount"));

    //3.1 swap all wBNB into USDT
    uint256 constant PERCENTAGE_SWAP = 1000;
    bytes32 constant SWAPPED_AMOUNT_KEY = bytes32(bytes("swapped_amount"));

    //3.2 Repay 100% of USDT
    uint256 constant REAY_PERCENTAGE = 10000;
    bytes32 constant REPAY_AMOUNT = bytes32(bytes("repay_amount"));

    //3.3 Calculate provide lp amount
    bytes32 constant PROVIDE_LP_AMOUNT_KEY = bytes32(bytes("provide_lp_amount"));

    address public EXECUTOR = makeAddr("executor");
    address public TRADER = makeAddr("trader");

    function setUp() public {
        baseFork = vm.createFork(BNB_FORK);
        vm.selectFork(baseFork);
    }

    function test_activate_automation() external {
        uint32 conditionId = 10021;

        // uint32 automationId = 10021;
        uint32 automationId = 10021;

        uint32 strategyId = 1001;
        vm.mockCall(
            0x8e61B06eDEF8557CD1e4F530d96B22736Fcb34e0,
            abi.encodeWithSelector(ICondition.checkCondition.selector),
            abi.encode(1)
        );

        //     conditionAddress: 0x43FB488Eaa15deE312283d27d4cf89Cd26d01d0d,
        //     result0: 0,
        //     result1: 1,
        //     id: conditionId
        // });

        // address multisig = 0x56B2cC86A6d1Da4Bc5567B4925dbeb8d746e5E86;
        vm.prank(wallet);
        // IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).executeAutomation(automationId, wallet, EXECUTOR);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).executeStrategy(strategyId);
    }

    function test_automationExecution() external {
        deal(wallet, 21 ether);

        executeFirstStrategy();

        createSecondStrategy();

        createThirdStrategy();

        // checkRangeCondition();
        changePriceToUpperAndExecute();

        // mockTimeAndExecute();
    }

    function checkRangeCondition() internal view {
        uint256 lpPosition = abi.decode(
            IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).getContextVariable(wallet, CONTEXT_ID, LP_POSITION_KEY),
            (uint256)
        );

        (,,,,, int24 tickLower,,,,, uint128 token0Owed, uint128 token1Owed) =
            INonfungiblePositionManager(PANCAKE_SWAP_V3_POSITION_MANAGER).positions(lpPosition);

        (, int24 tick,,,,,) = IPancakeSwapPoolState(PANCAKE_SWAP_POOL).slot0();

        uint8 isTrue = IPancakeSwapV3PositionRangeChecker(PANCAKE_SWAP_V3_POSITION_RANGE_CHECKER).checkCondition(
            wallet, CONDITION_ID_LOWER_TICK
        );

        console2.log("==============================");
        console2.log("=== Strategy 3 Information ===");
        console2.log("Lower tick trigger", tickLower);
        console2.log("Current tick", tick);
        console2.log("Is tick out of range", isTrue == 1);
        console2.log("Token0 Owed", _toDecimalString(token0Owed, 18));
        console2.log("Token1 Owed", _toDecimalString(token1Owed, 18));
    }

    function changePriceToUpperAndExecute() internal {
        deal(USDT, TRADER, 80000000 ether);
        for (uint256 i; i < 30; i++) {
            _mockSwap(USDT, 90000 ether, TRADER);
        }

        deal(wBNB, TRADER, 10 ether);
        _mockSwap(wBNB, 10 ether, TRADER);

        checkRangeCondition();

        uint256 usdtBalanceBefore = IERC20(USDT).balanceOf(wallet);

        console2.log("USD Amount before execution!");
        console2.log("USDT  Amount:", _toDecimalString(usdtBalanceBefore, 18));

        vm.prank(EXECUTOR);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).executeAutomation(STRATEGY_ID_LOWER_TICK, wallet, EXECUTOR);

        uint256 removeLpAmount = abi.decode(
            IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).getContextVariable(wallet, CONTEXT_ID, REMOVE_LP_AMOUNT_KEY),
            (uint256)
        );

        uint256 swappedAmount = abi.decode(
            IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).getContextVariable(wallet, CONTEXT_ID, SWAPPED_AMOUNT_KEY),
            (uint256)
        );

        uint256 provideLPAmount = abi.decode(
            IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).getContextVariable(
                wallet, CONTEXT_ID, PROVIDE_LP_AMOUNT_KEY
            ),
            (uint256)
        );
        uint256 repayAmount = abi.decode(
            IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).getContextVariable(wallet, CONTEXT_ID, REPAY_AMOUNT),
            (uint256)
        );
        uint256 borrowedAmount = abi.decode(
            IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).getContextVariable(wallet, CONTEXT_ID, BORROW_AMOUNT_KEY),
            (uint256)
        );
        console2.log("=== Strategy 3 Execution ===");
        console2.log("Remove LP amount", _toDecimalString(removeLpAmount, 18));
        console2.log("Swapped Amount", _toDecimalString(swappedAmount, 18));
        console2.log("Repay Amount", _toDecimalString(repayAmount, 18));
        console2.log("Borrowed Amount", _toDecimalString(borrowedAmount, 18));

        console2.log("=============================");
        uint256 wBNBAmount = IERC20(wBNB).balanceOf(wallet);
        console2.log("BNB Amount after execution!");
        console2.log("wBNB Amount:", _toDecimalString(wBNBAmount, 18));

        uint256 usdtBalance = IERC20(USDT).balanceOf(wallet);

        console2.log("USD Amount after execution!");
        console2.log("USDT  Amount:", _toDecimalString(usdtBalance, 18));
        console2.log("Provide LP Amount:", _toDecimalString(provideLPAmount, 18));
    }

    function createThirdStrategy() internal {
        IStrategyBuilderModule.StrategyStep[] memory steps = new IStrategyBuilderModule.StrategyStep[](3);

        IStrategyBuilderModule.Action[] memory firstStepActions = new IStrategyBuilderModule.Action[](4);
        IStrategyBuilderModule.Action[] memory secondStepActions = new IStrategyBuilderModule.Action[](1);
        IStrategyBuilderModule.Action[] memory thirdStepActions = new IStrategyBuilderModule.Action[](4);

        // First Step always remove lp
        IStrategyBuilderModule.ContextKey[] memory inputs = new IStrategyBuilderModule.ContextKey[](1);
        inputs[0] = IStrategyBuilderModule.ContextKey({
            key: LP_POSITION_KEY,
            parameterReplacement: IStrategyBuilderModule.Parameter({
                offset: 32,
                length: 32,
                paramType: IStrategyBuilderModule.ParamType.UINT256
            })
        });

        firstStepActions[0] = IStrategyBuilderModule.Action({
            selector: IPancakeSwapV3LPActions.removeLiquidityPercentage.selector,
            parameter: abi.encode(wallet, 0, PERCENTAGE_LP),
            value: 0,
            target: PANCAKE_SWAP_V3_LP_ACTIONS,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: inputs, // LP position ID
            output: IStrategyBuilderModule.ContextKey({ // Empty struct
                key: REMOVE_LP_AMOUNT_KEY,
                parameterReplacement: IStrategyBuilderModule.Parameter({
                    offset: 0,
                    length: 32,
                    paramType: IStrategyBuilderModule.ParamType.UINT256
                })
            }),
            result: 1
        });

        firstStepActions[1] = IStrategyBuilderModule.Action({
            selector: IStrategyBuilderModule.storeConextVariable.selector,
            parameter: abi.encode(CONTEXT_ID, SWAPPED_AMOUNT_KEY, IStrategyBuilderModule.ParamType.UINT256, abi.encode(0)),
            value: 0,
            target: STRATEGY_BUILDER_PLUGIN,
            actionType: IStrategyBuilderModule.ActionType.EXTERNAL,
            inputs: new IStrategyBuilderModule.ContextKey[](0), // LP position ID
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

        firstStepActions[2] = IStrategyBuilderModule.Action({
            selector: IStrategyBuilderModule.storeConextVariable.selector,
            parameter: abi.encode(CONTEXT_ID, REPAY_AMOUNT, IStrategyBuilderModule.ParamType.UINT256, abi.encode(0)),
            value: 0,
            target: STRATEGY_BUILDER_PLUGIN,
            actionType: IStrategyBuilderModule.ActionType.EXTERNAL,
            inputs: new IStrategyBuilderModule.ContextKey[](0), // LP position ID
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

        firstStepActions[3] = IStrategyBuilderModule.Action({
            selector: IStrategyBuilderModule.storeConextVariable.selector,
            parameter: abi.encode(CONTEXT_ID, BORROW_AMOUNT_KEY, IStrategyBuilderModule.ParamType.UINT256, abi.encode(0)),
            value: 0,
            target: STRATEGY_BUILDER_PLUGIN,
            actionType: IStrategyBuilderModule.ActionType.EXTERNAL,
            inputs: new IStrategyBuilderModule.ContextKey[](0), // LP position ID
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
            condition: IStrategyBuilderModule.Condition({conditionAddress: address(0), id: 0, result0: 0, result1: 1}),
            actions: firstStepActions
        });

        // Second Step: swapp all wBNB if some exist

        IStrategyBuilderModule.Condition memory coinBalanceCondition = IStrategyBuilderModule.Condition({
            conditionAddress: ERC20_TOKEN_BALANCE_CONDITION,
            id: STRATEGY_ID_LOWER_TICK,
            result0: 2,
            result1: 2
        });

        secondStepActions[0] = IStrategyBuilderModule.Action({
            selector: IPancakeSwapV3SwapActions.swapInputSinglePercentage.selector,
            parameter: abi.encode(wallet, PERCENTAGE_SWAP, wBNB, USDT, POOL_FEE, false),
            value: 0,
            target: PANCAKE_SWAP_V3_SWAP_ACTIONS,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: new IStrategyBuilderModule.ContextKey[](0), // LP position ID
            output: IStrategyBuilderModule.ContextKey({ // Empty struct
                key: SWAPPED_AMOUNT_KEY,
                parameterReplacement: IStrategyBuilderModule.Parameter({
                    offset: 0,
                    length: 32,
                    paramType: IStrategyBuilderModule.ParamType.UINT256
                })
            }),
            result: 2
        });

        steps[1] = IStrategyBuilderModule.StrategyStep({condition: coinBalanceCondition, actions: secondStepActions});

        // // Third Step: adjust aave position and provide lp again

        thirdStepActions[0] = IStrategyBuilderModule.Action({
            selector: IAaveV3Actions.repayPercentageOfBalance.selector,
            parameter: abi.encode(wallet, USDT, REAY_PERCENTAGE, 2),
            value: 0,
            target: AAVE_V3_Actions,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: new IStrategyBuilderModule.ContextKey[](0), // LP position ID
            output: IStrategyBuilderModule.ContextKey({ // Empty struct
                key: REPAY_AMOUNT,
                parameterReplacement: IStrategyBuilderModule.Parameter({
                    offset: 0,
                    length: 32,
                    paramType: IStrategyBuilderModule.ParamType.UINT256
                })
            }),
            result: 2
        });

        thirdStepActions[1] = IStrategyBuilderModule.Action({
            selector: IAaveV3Actions.borrowToHealthFactor.selector,
            parameter: abi.encode(wallet, USDT, HEALTH_FACTOR, INTEREST_RATE_MODE),
            value: 0,
            target: AAVE_V3_Actions,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: new IStrategyBuilderModule.ContextKey[](0), // Empty array
            output: IStrategyBuilderModule.ContextKey({ // save the borrowed amount into context
                key: BORROW_AMOUNT_KEY,
                parameterReplacement: IStrategyBuilderModule.Parameter({
                    offset: 0,
                    length: 32,
                    paramType: IStrategyBuilderModule.ParamType.UINT256
                })
            }),
            result: 0
        });

        // add the total amount that i want to provide as lp
        MathAction.MathParams[] memory mathParams = new MathAction.MathParams[](3);
        mathParams[0] = MathAction.MathParams({op: MathAction.Op.ADD, a: REMOVE_LP_AMOUNT_KEY, b: SWAPPED_AMOUNT_KEY});
        mathParams[1] = MathAction.MathParams({op: MathAction.Op.SUB, a: bytes32(0), b: REPAY_AMOUNT});
        mathParams[2] = MathAction.MathParams({op: MathAction.Op.ADD, a: bytes32(0), b: BORROW_AMOUNT_KEY});

        thirdStepActions[2] = IStrategyBuilderModule.Action({
            selector: MathAction.executeBatch.selector,
            parameter: abi.encode(wallet, CONTEXT_ID, mathParams),
            value: 0,
            target: MATH_ACTION,
            actionType: IStrategyBuilderModule.ActionType.EXTERNAL,
            inputs: new IStrategyBuilderModule.ContextKey[](0), // Empty array
            output: IStrategyBuilderModule.ContextKey({ // save the borrowed amount into context
                key: PROVIDE_LP_AMOUNT_KEY,
                parameterReplacement: IStrategyBuilderModule.Parameter({
                    offset: 0,
                    length: 32,
                    paramType: IStrategyBuilderModule.ParamType.UINT256
                })
            }),
            result: 0
        });

        IStrategyBuilderModule.ContextKey[] memory lpInputs = new IStrategyBuilderModule.ContextKey[](1);
        lpInputs[0] = IStrategyBuilderModule.ContextKey({
            key: PROVIDE_LP_AMOUNT_KEY,
            parameterReplacement: IStrategyBuilderModule.Parameter({
                offset: 32,
                length: 32,
                paramType: IStrategyBuilderModule.ParamType.UINT256
            })
        });

        thirdStepActions[3] = IStrategyBuilderModule.Action({
            selector: IUniswapV3OneSidedLPActions.addLiquidityOneSidedPercentageRange.selector,
            parameter: abi.encode(PERCENTAGE, 0, LP_PARAMS),
            value: 0,
            target: PANCAKE_SWAP_V3_ONE_SIDED_LP_ACTIONS,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: lpInputs, // provide one sidedd with the total borrow amount
            output: IStrategyBuilderModule.ContextKey({ // Empty struct
                key: LP_POSITION_KEY,
                parameterReplacement: IStrategyBuilderModule.Parameter({
                    offset: 0,
                    length: 32,
                    paramType: IStrategyBuilderModule.ParamType.UINT256
                })
            }),
            result: 2
        });

        steps[2] = IStrategyBuilderModule.StrategyStep({
            condition: IStrategyBuilderModule.Condition({conditionAddress: address(0), id: 0, result0: 0, result1: 0}),
            actions: thirdStepActions
        });

        vm.prank(wallet);
        CoinOrERC20BalanceCondition(ERC20_TOKEN_BALANCE_CONDITION).addCondition(
            STRATEGY_ID_LOWER_TICK,
            ICoinOrERC20BalanceCondition.Condition({
                baseToken: wBNB,
                amount: 0,
                comparison: ICoinOrERC20BalanceCondition.Comparison.GREATER,
                updateable: true
            })
        );

        vm.prank(wallet);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).createStrategyWithExistingContext(
            STRATEGY_ID_LOWER_TICK, address(0), steps, CONTEXT_ID
        );

        vm.prank(wallet);
        IPancakeSwapV3PositionRangeChecker(PANCAKE_SWAP_V3_POSITION_RANGE_CHECKER).addCondition(
            CONDITION_ID_LOWER_TICK,
            IPancakeSwapV3PositionRangeChecker.Condition({
                contextId: CONTEXT_ID,
                contextKey: LP_POSITION_KEY,
                rangeCheck: IPancakeSwapV3PositionRangeChecker.PositionRangeStatusCheck.UnderLowerRange,
                updateable: true
            })
        );

        IStrategyBuilderModule.Condition memory condition = IStrategyBuilderModule.Condition({
            conditionAddress: PANCAKE_SWAP_V3_POSITION_RANGE_CHECKER,
            id: CONDITION_ID_LOWER_TICK,
            result0: 0,
            result1: 0
        });

        vm.prank(wallet);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).createAutomation(
            STRATEGY_ID_LOWER_TICK, STRATEGY_ID_LOWER_TICK, address(0), type(uint256).max, condition
        );
    }

    function createSecondStrategy() internal {
        IStrategyBuilderModule.StrategyStep[] memory steps = new IStrategyBuilderModule.StrategyStep[](1);

        IStrategyBuilderModule.Action[] memory actions = new IStrategyBuilderModule.Action[](3);

        IStrategyBuilderModule.ContextKey[] memory inputs = new IStrategyBuilderModule.ContextKey[](1);
        inputs[0] = IStrategyBuilderModule.ContextKey({
            key: LP_POSITION_KEY,
            parameterReplacement: IStrategyBuilderModule.Parameter({
                offset: 0,
                length: 32,
                paramType: IStrategyBuilderModule.ParamType.UINT256
            })
        });

        actions[0] = IStrategyBuilderModule.Action({
            selector: IPancakeSwapV3LPActions.collect.selector,
            parameter: abi.encode(COLLECT_PARAMS),
            value: 0,
            target: PANCAKE_SWAP_V3_LP_ACTIONS,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: inputs, // LP position ID
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
            selector: IAaveV3Actions.supplyPercentageOfBalance.selector,
            parameter: abi.encode(wallet, wBNB, PERCENTAGE_AAVE),
            value: 0,
            target: AAVE_V3_Actions,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: new IStrategyBuilderModule.ContextKey[](0), // Supply amount from context
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

        actions[2] = IStrategyBuilderModule.Action({
            selector: IAaveV3Actions.repayPercentageOfBalance.selector,
            parameter: abi.encode(wallet, USDT, PERCENTAGE_AAVE, 2),
            value: 0,
            target: AAVE_V3_Actions,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: new IStrategyBuilderModule.ContextKey[](0), // Supply amount from context
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

        vm.prank(wallet);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).createStrategyWithExistingContext(
            STRATEGY_ID_INTERVAL, address(0), steps, CONTEXT_ID
        );

        //add the condition
        vm.prank(wallet);
        TimeCondition(TIME_CONDITION).addCondition(
            CONDITION_ID_INTERVAL,
            ITimeCondition.Condition({
                execution: block.timestamp + DELTA_INTERVAL,
                delta: DELTA_INTERVAL,
                updateable: true
            })
        );

        IStrategyBuilderModule.Condition memory condition = IStrategyBuilderModule.Condition({
            conditionAddress: TIME_CONDITION,
            id: CONDITION_ID_INTERVAL,
            result0: 0,
            result1: 0
        });

        vm.prank(wallet);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).createAutomation(
            STRATEGY_ID_INTERVAL, STRATEGY_ID_INTERVAL, address(0), type(uint256).max, condition
        );

        console2.log("==============================");
        console2.log("=== Strategy 2 Information ===");
        console2.log("Next Execution:", block.timestamp + DELTA_INTERVAL);
        console2.log("Current time:", block.timestamp);
    }

    function mockTimeAndExecute() internal {
        for (uint256 i; i < 1000; i++) {
            deal(USDT, TRADER, 80000 ether);
            _mockSwap(USDT, 80000 ether, TRADER);

            deal(wBNB, TRADER, 80 ether);
            _mockSwap(wBNB, 80 ether, TRADER);
        }

        vm.warp(block.timestamp + DELTA_INTERVAL);
        console2.log("=============================");
        uint256 aBNBBalanceBeforeExecution = IERC20(aBNB).balanceOf(wallet);
        console2.log("BNB Amount before execution Supplied!");
        console2.log("aBNB Amount:", _toDecimalString(aBNBBalanceBeforeExecution, 18));

        uint256 usdtBalanceBeforeExecution = IERC20(debtUSDT).balanceOf(wallet);

        console2.log("USD Amount before execution Borrowed!");
        console2.log("USDT debt Amount:", _toDecimalString(usdtBalanceBeforeExecution, 18));

        vm.prank(EXECUTOR);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).executeAutomation(STRATEGY_ID_INTERVAL, wallet, EXECUTOR);

        console2.log("=============================");
        console2.log("=== Strategy 2 Execution ===");
        uint256 aBNBBalance = IERC20(aBNB).balanceOf(wallet);
        console2.log("Fees collected and supplied and repayed!");
        console2.log("aBNB Amount:", _toDecimalString(aBNBBalance - aBNBBalanceBeforeExecution, 18));

        uint256 usdtBalance = IERC20(debtUSDT).balanceOf(wallet);

        console2.log("USDT debt Amount:", _toDecimalString(usdtBalanceBeforeExecution - usdtBalance, 18));

        ITimeCondition.Condition memory conditionInfo =
            TimeCondition(TIME_CONDITION).walletCondition(wallet, CONDITION_ID_INTERVAL);
        console2.log("Next Execution:", conditionInfo.execution);
    }

    function executeFirstStrategy() internal {
        IStrategyBuilderModule.StrategyStep[] memory steps = new IStrategyBuilderModule.StrategyStep[](1);

        IStrategyBuilderModule.Action[] memory actions = new IStrategyBuilderModule.Action[](3);

        IStrategyBuilderModule.ContextKey[] memory inputs = new IStrategyBuilderModule.ContextKey[](1);
        inputs[0] = IStrategyBuilderModule.ContextKey({
            key: SUPPLY_AMOUNT_KEY,
            parameterReplacement: IStrategyBuilderModule.Parameter({
                offset: 32,
                length: 32,
                paramType: IStrategyBuilderModule.ParamType.UINT256
            })
        });

        actions[0] = IStrategyBuilderModule.Action({
            selector: IAaveV3Actions.supplyETH.selector,
            parameter: abi.encode(wallet, AMOUNT),
            value: 0,
            target: AAVE_V3_Actions,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: inputs, // Supply amount from context
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
            parameter: abi.encode(wallet, USDT, HEALTH_FACTOR, INTEREST_RATE_MODE),
            value: 0,
            target: AAVE_V3_Actions,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: new IStrategyBuilderModule.ContextKey[](0), // Empty array
            output: IStrategyBuilderModule.ContextKey({ // save the borrowed amount into context
                key: BORROW_AMOUNT_KEY,
                parameterReplacement: IStrategyBuilderModule.Parameter({
                    offset: 0,
                    length: 32,
                    paramType: IStrategyBuilderModule.ParamType.UINT256
                })
            }),
            result: 0
        });

        IStrategyBuilderModule.ContextKey[] memory lpInputs = new IStrategyBuilderModule.ContextKey[](1);
        lpInputs[0] = IStrategyBuilderModule.ContextKey({
            key: BORROW_AMOUNT_KEY,
            parameterReplacement: IStrategyBuilderModule.Parameter({
                offset: 32,
                length: 32,
                paramType: IStrategyBuilderModule.ParamType.UINT256
            })
        });

        actions[2] = IStrategyBuilderModule.Action({
            selector: IUniswapV3OneSidedLPActions.addLiquidityOneSidedPercentageRange.selector,
            parameter: abi.encode(PERCENTAGE, 0, LP_PARAMS),
            value: 0,
            target: PANCAKE_SWAP_V3_ONE_SIDED_LP_ACTIONS,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: lpInputs, // provide one sidedd with the total borrow amount
            output: IStrategyBuilderModule.ContextKey({ // Empty struct
                key: LP_POSITION_KEY,
                parameterReplacement: IStrategyBuilderModule.Parameter({
                    offset: 0,
                    length: 32,
                    paramType: IStrategyBuilderModule.ParamType.UINT256
                })
            }),
            result: 2
        });

        steps[0] = IStrategyBuilderModule.StrategyStep({
            condition: IStrategyBuilderModule.Condition({conditionAddress: address(0), id: 0, result0: 0, result1: 0}),
            actions: actions
        });

        vm.prank(wallet);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).storeConextVariable(
            CONTEXT_ID, SUPPLY_AMOUNT_KEY, IStrategyBuilderModule.ParamType.UINT256, abi.encode(AMOUNT)
        );

        vm.prank(wallet);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).createStrategyWithExistingContext(
            STRATEGY_ID, address(0), steps, CONTEXT_ID
        );

        vm.prank(wallet);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).executeStrategy(STRATEGY_ID);
        console2.log("=== Strategy 1 Information ===");
        uint256 aBNBBalance = IERC20(aBNB).balanceOf(wallet);
        console2.log("BNB Amount Supplied!");
        console2.log("aBNB Amount:", _toDecimalString(aBNBBalance, 18));

        assertTrue(aBNBBalance > 0);

        uint256 usdtBalance = IERC20(debtUSDT).balanceOf(wallet);

        console2.log("USD Amount Borrowed!");
        console2.log("USDT debt Amount:", _toDecimalString(usdtBalance, 18));

        uint256 borrowAmount = abi.decode(
            IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).getContextVariable(wallet, CONTEXT_ID, BORROW_AMOUNT_KEY),
            (uint256)
        );
        console2.log("Borrow Amount:", _toDecimalString(borrowAmount, 18));

        uint256 lpPosition = abi.decode(
            IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).getContextVariable(wallet, CONTEXT_ID, LP_POSITION_KEY),
            (uint256)
        );
        console2.log("LP Position:", lpPosition);

        console2.log("=============================");
        uint256 wBNBAmountAfter = IERC20(wBNB).balanceOf(wallet);
        console2.log("BNB Amount after execution!");
        console2.log("wBNB Amount:", _toDecimalString(wBNBAmountAfter, 18));

        uint256 usdtBalanceAfter = IERC20(USDT).balanceOf(wallet);

        console2.log("USD Amount after execution!");
        console2.log("USDT  Amount:", _toDecimalString(usdtBalanceAfter, 18));

        console2.log("=============================");
        uint256 wBNBAmountZapper = IERC20(wBNB).balanceOf(0xbC7Ed7324D8B9a400Cf8045A6eEFED9D56B5a84E);
        console2.log("BNB Amount after execution!");
        console2.log("wBNB Amount Zapper:", _toDecimalString(wBNBAmountZapper, 18));

        uint256 usdtBalanceZapper = IERC20(USDT).balanceOf(0xbC7Ed7324D8B9a400Cf8045A6eEFED9D56B5a84E);

        console2.log("USD Amount after execution!");
        console2.log("USDT  Amount Zapper:", _toDecimalString(usdtBalanceZapper, 18));
    }

    function _toDecimalString(uint256 amount, uint8 decimals) internal pure returns (string memory) {
        uint256 integerPart = amount / 10 ** decimals;
        uint256 fractionalPart = amount % 10 ** decimals;

        // Trim leading zeros in fractional part for cleaner output
        string memory frac = vm.toString(fractionalPart);
        while (bytes(frac).length < decimals) {
            frac = string.concat("0", frac);
        }

        // Optional: limit to, e.g., 4 decimals for display
        bytes memory fracBytes = bytes(frac);
        if (fracBytes.length > 4) {
            assembly {
                mstore(fracBytes, 4)
            }
        }

        return string.concat(vm.toString(integerPart), ".", string(fracBytes));
    }

    function _mockSwap(address tokenIn, uint256 amountIn, address swapAccount) public returns (uint256 amountOut) {
        // Approve router for swapping
        vm.prank(swapAccount);
        IERC20(tokenIn).approve(PANCAKE_SWAP_V3_ROUTER, amountIn);

        // Build the V3 path: tokenIn -> fee -> tokenOut
        bytes memory path = abi.encodePacked(tokenIn == USDT ? USDT : wBNB, POOL_FEE, tokenIn == USDT ? wBNB : USDT);

        IPancakeV3RouterMinimal.ExactInputParams memory params = IPancakeV3RouterMinimal.ExactInputParams({
            path: path,
            recipient: swapAccount,
            amountIn: amountIn,
            amountOutMinimum: 0 // no slippage protection for testing
        });

        // Perform the swap
        vm.prank(swapAccount);
        amountOut = IPancakeV3RouterMinimal(PANCAKE_SWAP_V3_ROUTER).exactInput(params);

        return amountOut;
    }
}

interface IPancakeV3RouterMinimal {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

interface IPancakeSwapPoolState {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint32 feeProtocol,
            bool unlocked
        );

    function liquidity() external view returns (uint128);

    function tickSpacing() external view returns (int24);

    function token0() external view returns (address);

    function token1() external view returns (address);
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

/// @title IUniswapV3OneSidedLPAction
/// @notice Interface for UniswapV3OneSidedLPAction
interface IUniswapV3OneSidedLPActions is IAction {
    /// @notice Input parameters for adding one-sided liquidity
    struct AddLiquidityOneSidedParams {
        address tokenIn;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        address recipient;
    }

    /// @notice Input parameters for one-sided liquidity with percentage-based range
    struct AddLiquidityOneSidedRangeParams {
        address tokenIn;
        address token0;
        address token1;
        uint24 fee;
        address recipient;
    }

    /// @notice Input parameters for removing one-sided liquidity
    struct RemoveLiquidityOneSidedParams {
        uint256 tokenId;
        address tokenOut;
    }

    // --- View / External functions ---

    /// @notice Adds liquidity to a Uniswap V3 pool using only one token.
    /// @param amountIn amount of tokenIn to use
    /// @param params pool and token configuration
    /// @return executions list of PluginExecution to perform
    function addLiquidityOneSided(uint256 amountIn, AddLiquidityOneSidedParams calldata params)
        external
        view
        returns (PluginExecution[] memory executions);

    /// @notice Adds liquidity within a percentage-based range using one token.
    /// @param percentage percentage defining the range width (approx)
    /// @param amountIn amount of tokenIn to use
    /// @param params base pool configuration
    /// @return executions list of PluginExecution to perform
    function addLiquidityOneSidedPercentageRange(
        uint24 percentage,
        uint256 amountIn,
        AddLiquidityOneSidedRangeParams calldata params
    ) external view returns (PluginExecution[] memory executions);

    /// @notice Identifier for the action
    /// @return bytes4 action identifier
    function identifier() external pure returns (bytes4);

    /// @notice EIP-165 style interface support
    /// @param interfaceId interface id to check
    /// @return true if supported
    function supportsInterface(bytes4 interfaceId) external pure returns (bool);
}

interface IPancakeSwapV3LPActions is IAction {
    // ┏━━━━━━━━━━━━━━┓
    // ┃   Structs    ┃
    // ┗━━━━━━━━━━━━━━┛

    struct AddLiqudityParams {
        address wallet;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct AddLiqudityPercentageParams {
        address wallet;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 percentage;
    }

    struct RemoveLiquidityParams {
        address wallet;
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct RemoveLiquidityPercentageParams {
        address wallet;
        uint256 tokenId;
        uint256 percentage;
    }

    struct AddLiqudityWithOneTokenParams {
        address wallet;
        address token0;
        address token1;
        bool token0In;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount;
    }

    // ┏━━━━━━━━━━━━━━┓
    // ┃    Errors    ┃
    // ┗━━━━━━━━━━━━━━┛

    error InvalidTokenGetterID();

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Public Basic Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    function mint(INonfungiblePositionManager.MintParams memory params, bool payNative)
        external
        view
        returns (PluginExecution[] memory);

    function burn(uint256 tokenId) external view returns (PluginExecution[] memory);

    function collect(INonfungiblePositionManager.CollectParams memory params)
        external
        view
        returns (PluginExecution[] memory);

    function decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams memory params)
        external
        view
        returns (PluginExecution[] memory);

    function increaseLiquidity(INonfungiblePositionManager.IncreaseLiquidityParams memory params, bool payNative)
        external
        view
        returns (PluginExecution[] memory);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Public Special Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function addLiqudity(AddLiqudityParams memory params) external view returns (PluginExecution[] memory);

    function addLiqudityPercentage(AddLiqudityPercentageParams memory params)
        external
        view
        returns (PluginExecution[] memory);

    function removeLiquidity(address wallet, uint256 tokenId, uint128 liquidity, uint256 amount0Min, uint256 amount1Min)
        external
        view
        returns (PluginExecution[] memory);

    function removeLiquidityPercentage(address wallet, uint256 tokenId, uint256 percentage)
        external
        view
        returns (PluginExecution[] memory);
}

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}

interface IPancakeSwapV3PositionRangeChecker {
    // -------------------------
    // Enums
    // -------------------------
    enum PositionRangeStatusCheck {
        InRange,
        UnderLowerRange,
        OverUpperRange
    }

    // -------------------------
    // Structs
    // -------------------------
    struct Condition {
        bytes32 contextId;
        bytes32 contextKey;
        PositionRangeStatusCheck rangeCheck;
        bool updateable;
    }

    // -------------------------
    // Events
    // -------------------------
    event ConditionAdded(uint32 id, address wallet, Condition condition);

    // -------------------------
    // Functions
    // -------------------------

    function addCondition(uint32 _id, Condition calldata condition) external;

    function deleteCondition(uint32 _id) external;

    function checkCondition(address wallet, uint32 id) external view returns (uint8);

    function walletCondition(address _wallet, uint32 _id) external view returns (Condition memory);
}

interface IPancakeSwapV3SwapActions is IAction {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    View Getters           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function router() external view returns (address);
    function WETH() external view returns (address);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Swap Standard Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function swapExactInputSingle(
        address wallet,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        bool native
    ) external view returns (PluginExecution[] memory);

    function swapExactInput(
        address wallet,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata path,
        bool native
    ) external view returns (PluginExecution[] memory);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Swap Percentage Functions   ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function swapInputSinglePercentage(
        address wallet,
        uint256 percentage,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        bool native
    ) external view returns (PluginExecution[] memory);

    function swapInputPercentage(address wallet, uint256 percentage, bytes calldata path)
        external
        view
        returns (PluginExecution[] memory);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Identifiers            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function identifier() external pure returns (bytes4);

    function supportsInterface(bytes4 interfaceId) external pure returns (bool);
}
