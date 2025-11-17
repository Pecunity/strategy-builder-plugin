// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IStrategyBuilderModule} from "../../contracts/interfaces/IStrategyBuilderModule.sol";
import {IAction} from "../../contracts/interfaces/IAction.sol";
import {ITokenGetter} from "../../contracts/interfaces/ITokenGetter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TimeCondition} from "../../contracts/condition/examples/TimeCondition.sol";
import {ITimeCondition} from "../../contracts/condition/examples/interfaces/ITimeCondition.sol";

contract StrategyExecutionTest is Test {
    string BNB_FORK = vm.envString("BNB_FORK");
    uint256 baseFork;

    address wallet = 0x25cc8eE8efDFd50D063A717363D099E92EBc56b7;

    address public constant STRATEGY_BUILDER_PLUGIN = 0x4095B6aC5abbDEFFb690447dF6F487E8a2B387DF;
    address public constant AAVE_V3_Actions = 0x8C262ec2db34a6CdA55ba9aDe792225191e0754C;
    address public constant PANCAKE_SWAP_V3_ONE_SIDED_LP_ACTIONS = 0x2A9b50800138a9841Fc9789c2708219073997786;
    address public constant PANCAKE_SWAP_V3_LP_ACTIONS = 0xc12376C08c26eE282589682C65D87772AdFD9F40;
    address public constant TIME_CONDITION = 0x43FB488Eaa15deE312283d27d4cf89Cd26d01d0d;

    address public constant PANCAKE_SWAP_V3_ROUTER = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;

    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public constant aBNB = 0x9B00a09492a626678E5A3009982191586C444Df9;
    address public constant wBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant debtUSDT = 0xF8bb2Be50647447Fb355e3a77b81be4db64107cd;

    //setUp

    bytes32 public constant CONTEXT_ID = 0x8b4a89e6f417d4f7d47e91bde9f5e3e65d73013e0b77b4acdb8b12947a0cd82c;
    uint32 public constant STRATEGY_ID = 3155266195;

    //1.1 Supply wBNB
    uint256 constant AMOUNT = 20 ether;
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
    uint24 constant PERCENTAGE = 1250;
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

    address public EXECUTOR = makeAddr("executor");
    address public TRADER = makeAddr("trader");

    function setUp() public {
        baseFork = vm.createFork(BNB_FORK);
        vm.selectFork(baseFork);
    }

    function test_automationExecution() external {
        deal(wallet, 21 ether);

        executeFirstStrategy();

        createSecondStrategy();

        mockTimeAndExecute();
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
        for (uint256 i; i < 100; i++) {
            deal(USDT, TRADER, 20000 ether);
            _mockSwap(USDT, 20000 ether, TRADER);

            deal(wBNB, TRADER, 20 ether);
            _mockSwap(wBNB, 20 ether, TRADER);
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
        console2.log("aBNB Amount:", (aBNBBalance - aBNBBalanceBeforeExecution));

        uint256 usdtBalance = IERC20(debtUSDT).balanceOf(wallet);

        console2.log("USDT debt Amount:", (usdtBalanceBeforeExecution - usdtBalance));

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
            parameter: abi.encode(wallet, 0),
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
}
