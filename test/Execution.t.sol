// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IStrategyBuilderModule} from "../../contracts/interfaces/IStrategyBuilderModule.sol";
import {IAction} from "../../contracts/interfaces/IAction.sol";
import {ITokenGetter} from "../../contracts/interfaces/ITokenGetter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StrategyExecutionTest is Test {
    string BNB_FORK = vm.envString("BNB_FORK");
    uint256 baseFork;

    address public constant STRATEGY_BUILDER_PLUGIN = 0x1c57461F160F3C1C5cF15457f05e71eA69AaE2eb;
    address public constant AAVE_V3_Actions = 0x8C262ec2db34a6CdA55ba9aDe792225191e0754C;
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public constant aBNB = 0x9B00a09492a626678E5A3009982191586C444Df9;

    //setUp

    bytes32 public constant CONTEXT_ID = 0x8b4a89e6f417d4f7d47e91bde9f5e3e65d73013e0b77b4acdb8b12947a0cd82c;
    uint32 public constant STRATEGY_ID = 3155266195;

    //1.1 Supply wBNB
    uint256 constant AMOUNT = 1 ether;
    string constant SUPPLY_AMOUNT = "supply";

    //1.2 Borrow USDT to HealthFactor
    uint256 constant HEALTH_FACTOR = 1.21 ether;
    uint256 constant INTEREST_RATE_MODE = 2;

    address public EXECUTOR = makeAddr("executor");

    function setUp() public {
        baseFork = vm.createFork(BNB_FORK);
        vm.selectFork(baseFork);
    }

    function test_automationExecution() external {
        address wallet = 0x25cc8eE8efDFd50D063A717363D099E92EBc56b7;

        deal(wallet, 2 ether);

        IStrategyBuilderModule.StrategyStep[] memory steps = new IStrategyBuilderModule.StrategyStep[](1);

        IStrategyBuilderModule.Action[] memory actions = new IStrategyBuilderModule.Action[](2);
        actions[0] = IStrategyBuilderModule.Action({
            selector: IAaveV3Actions.supplyETH.selector,
            parameter: abi.encode(wallet, AMOUNT),
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
            parameter: abi.encode(wallet, USDT, HEALTH_FACTOR, INTEREST_RATE_MODE),
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

        vm.prank(wallet);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).storeConextVariable(
            CONTEXT_ID, "0x22", IStrategyBuilderModule.ParamType.UINT256, abi.encode(AMOUNT)
        );

        vm.prank(wallet);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).createStrategy(STRATEGY_ID, address(0), steps);

        vm.prank(wallet);
        IStrategyBuilderModule(STRATEGY_BUILDER_PLUGIN).executeStrategy(STRATEGY_ID);

        uint256 aBNBBalance = IERC20(aBNB).balanceOf(wallet);
        console2.log("BNB Amount Supplied!");
        console2.log("aBNB Amount:", _toDecimalString(aBNBBalance, 18));

        assertTrue(aBNBBalance > 0);

        uint256 usdtBalance = IERC20(USDT).balanceOf(wallet);

        console2.log("USD Amount Borrowed!");
        console2.log("USDT Amount:", _toDecimalString(usdtBalance, 18));

        assertTrue(usdtBalance > 0);
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
