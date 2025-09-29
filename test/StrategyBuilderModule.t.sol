// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

// import {UpgradeableModularAccount} from "erc6900/reference-implementation/src/account/UpgradeableModularAccount.sol";
// import {SingleOwnerPlugin} from "erc6900/reference-implementation/src/plugins/owner/SingleOwnerPlugin.sol";
// import {ISingleOwnerPlugin} from "erc6900/reference-implementation/src/plugins/owner/ISingleOwnerPlugin.sol";
// import {MSCAFactoryFixture} from "erc6900/reference-implementation/test/mocks/MSCAFactoryFixture.sol";
import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";
import {EntryPoint} from "@eth-infinitism/account-abstraction/core/EntryPoint.sol";

// import {FunctionReference} from "erc6900/reference-implementation/src/interfaces/IPluginManager.sol";
// import {FunctionReferenceLib} from "erc6900/reference-implementation/src/helpers/FunctionReferenceLib.sol";

import {StrategyBuilderModule} from "contracts/StrategyBuilderModule.sol";
import {IStrategyBuilderModule} from "contracts/interfaces/IStrategyBuilderModule.sol";

import {ModularAccount} from "modular-account/src/account/ModularAccount.sol";
import {ExecutionInstallDelegate} from "modular-account/src/helpers/ExecutionInstallDelegate.sol";
import {SingleSignerValidationModule} from "modular-account/src/modules/validation/SingleSignerValidationModule.sol";

import {AccountFactoryTest} from "./utils/AccountFactoryTest.sol";

import {IModularAccount} from "@erc6900/reference-implementation/interfaces/IModularAccount.sol";
import {DIRECT_CALL_VALIDATION_ENTITY_ID} from "@erc6900/reference-implementation/helpers/Constants.sol";
import {ValidationConfigLib} from "@erc6900/reference-implementation/libraries/ValidationConfigLib.sol";

import {IFeeController} from "contracts/interfaces/IFeeController.sol";
import {IFeeHandler} from "contracts/interfaces/IFeeHandler.sol";
import {IActionRegistry} from "contracts/interfaces/IActionRegistry.sol";
import {BaseCondition} from "contracts/condition/BaseCondition.sol";

import {MockCondition} from "contracts/test/mocks/MockCondition.sol";
import {Token} from "contracts/test/mocks/MockToken.sol";
import {WrongInterfaceContract} from "contracts/test/mocks/WrongInterfaceContract.sol";
import {MockAction} from "contracts/test/mocks/MockAction.sol";

contract StrategyBuilderModuleTest is Test {
    //Modular Account
    IEntryPoint entryPoint;

    ModularAccount public accountImplementation;
    AccountFactoryTest public factory;
    address public factoryOwner;
    ExecutionInstallDelegate executionInstallDelegate;
    SingleSignerValidationModule singleSignerValidationModule;

    address owner1;
    uint256 owner1Key;
    ModularAccount public account1;

    StrategyBuilderModule strategyBuilderModule;

    //Mocks
    MockCondition mockCondition = new MockCondition();

    address feeHandler = makeAddr("feeHandler");
    address feeController = makeAddr("feeController");
    address actionRegistry = makeAddr("actionRegistry");
    address automationExecutor = makeAddr("automationExecutor");
    address beneficiary = makeAddr("beneficiary");
    address creator = makeAddr("creator");
    address tokenReceiver = makeAddr("tokenReceiver");

    uint256 constant TOKEN_SEND_AMOUNT = 1 ether;

    function setUp() public {
        entryPoint = IEntryPoint(address(new EntryPoint()));

        (owner1, owner1Key) = makeAddrAndKey("owner1");

        executionInstallDelegate = new ExecutionInstallDelegate();
        singleSignerValidationModule = new SingleSignerValidationModule();
        accountImplementation = new ModularAccount(entryPoint, executionInstallDelegate);

        factory = new AccountFactoryTest(entryPoint, accountImplementation, address(singleSignerValidationModule));

        account1 = factory.createAccount(owner1, 0, type(uint32).max);

        strategyBuilderModule = new StrategyBuilderModule(feeController, feeHandler, actionRegistry);

        deal(address(account1), 100 ether);

        vm.startPrank(address(account1));
        account1.installExecution(address(strategyBuilderModule), strategyBuilderModule.executionManifest(), "");

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IModularAccount.execute.selector;
        account1.installValidation(
            ValidationConfigLib.pack(
                address(strategyBuilderModule), DIRECT_CALL_VALIDATION_ENTITY_ID, false, false, false
            ),
            selectors,
            "",
            new bytes[](0)
        );
        vm.stopPrank();
        // account1.execute(tokenReceiver, 1 ether, "");
    }

    ////////////////////////////////
    ////// createStrategy //////////
    ////////////////////////////////

    function test_createStrategy_Success(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        StrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        uint32 strategyID = 222;
        vm.prank(address(account1));
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);

        //Assert
        StrategyBuilderModule.Strategy memory strategy = strategyBuilderModule.strategy(address(account1), strategyID);

        assertEq(strategy.creator, creator);
        assertEq(strategy.steps.length, numSteps);
    }

    function test_createStrategy_Revert_AlreadyExists(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        StrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;
        vm.prank(address(account1));
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);

        vm.expectRevert(IStrategyBuilderModule.StrategyAlreadyExist.selector);
        vm.prank(address(account1));
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Success_StepsWithCondition(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        StrategyBuilderModule.StrategyStep[] memory steps = _createStrategyStepsWithCondition(numSteps);

        uint32 strategyID = 222;
        vm.prank(address(account1));
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);

        //Assert
        IStrategyBuilderModule.Strategy memory strategy = strategyBuilderModule.strategy(address(account1), strategyID);

        assertEq(strategy.creator, creator);
        assertEq(strategy.steps.length, numSteps);

        assertTrue(mockCondition.strategies(address(account1), uint32(1)).length > 0);
    }

    function test_createStrategy_Success_SameConditionMultipleTimesInStrategy(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);

        uint32 conditionId = 22;
        IStrategyBuilderModule.StrategyStep[] memory steps =
            _createStrategyStepsWithSameCondition(numSteps, conditionId);

        uint32 strategyID = 222;
        vm.prank(address(account1));
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);

        //Assert
        IStrategyBuilderModule.Strategy memory strategy = strategyBuilderModule.strategy(address(account1), strategyID);
        assertEq(strategy.creator, creator);
        assertEq(strategy.steps.length, numSteps);
        assertTrue(mockCondition.strategies(address(account1), conditionId).length > 0);
        assertTrue(mockCondition.conditionInStrategy(address(account1), conditionId, strategyID));
    }

    function test_createStrategy_Revert_InvalidNextStepId(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategyStepsWithCondition(numSteps);

        steps[steps.length - 1].condition.result1 = 100; // Invalid next step ID

        uint32 strategyID = 222;
        vm.prank(address(account1));
        vm.expectRevert(IStrategyBuilderModule.InvalidNextStepIndex.selector);
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidAction_NoContract(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        address invalidAction = makeAddr("invalid-address");
        steps[0].actions[0].target = invalidAction;
        steps[0].actions[0].actionType = IStrategyBuilderModule.ActionType.INTERNAL_ACTION;

        vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(true));

        uint32 strategyID = 222;
        vm.prank(address(account1));
        vm.expectRevert(IStrategyBuilderModule.InvalidActionTarget.selector);
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidAction_NoInterface(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        Token invalidActionContract = new Token("Test", "TST", 1 ether);
        address invalidAction = address(invalidActionContract);
        steps[0].actions[0].target = invalidAction;
        steps[0].actions[0].actionType = IStrategyBuilderModule.ActionType.INTERNAL_ACTION;

        vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(true));

        uint32 strategyID = 222;
        vm.prank(address(account1));
        vm.expectRevert(IStrategyBuilderModule.InvalidActionTarget.selector);
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidAction_IncorrectInterface(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        WrongInterfaceContract invalidActionContract = new WrongInterfaceContract();
        address invalidAction = address(invalidActionContract);
        steps[0].actions[0].target = invalidAction;
        steps[0].actions[0].actionType = IStrategyBuilderModule.ActionType.INTERNAL_ACTION;

        vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(true));

        uint32 strategyID = 222;
        vm.prank(address(account1));
        vm.expectRevert(IStrategyBuilderModule.InvalidActionTarget.selector);
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidAction_ZeroAddress(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        address invalidAction = address(0);
        steps[0].actions[0].target = invalidAction;
        steps[0].actions[0].actionType = IStrategyBuilderModule.ActionType.EXTERNAL;

        vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(true));

        uint32 strategyID = 222;
        vm.prank(address(account1));
        vm.expectRevert(IStrategyBuilderModule.InvalidActionTarget.selector);
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidAction_NotRegistered(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        address invalidAction = makeAddr("not-regisstered");
        steps[0].actions[0].target = invalidAction;
        steps[0].actions[0].actionType = IStrategyBuilderModule.ActionType.INTERNAL_ACTION;

        vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(false));

        uint32 strategyID = 222;
        vm.prank(address(account1));
        vm.expectRevert(IStrategyBuilderModule.InvalidActionTarget.selector);
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidCondition_NoInterface(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        Token invalidConditionContract = new Token("test", "TST", 1 ether);
        steps[0].condition.conditionAddress = address(invalidConditionContract);

        uint32 strategyID = 222;
        vm.prank(address(account1));
        vm.expectRevert(IStrategyBuilderModule.InvalidCondition.selector);
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidCondition_IncorrectInterface(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        WrongInterfaceContract invalidConditionContract = new WrongInterfaceContract();
        steps[0].condition.conditionAddress = address(invalidConditionContract);

        uint32 strategyID = 222;
        vm.prank(address(account1));
        vm.expectRevert(IStrategyBuilderModule.InvalidCondition.selector);
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidCondition_NoContract(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        steps[0].condition.conditionAddress = makeAddr("no-contract-address");

        uint32 strategyID = 222;
        vm.startPrank(address(account1));
        vm.expectRevert(IStrategyBuilderModule.InvalidConditionAddress.selector);
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);
        vm.stopPrank();
    }

    function test_createStrategy_Empty() external {
        uint256 numSteps;
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;
        vm.prank(address(account1));
        vm.expectRevert(IStrategyBuilderModule.InvalidStepArrayLength.selector);

        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_EmptyNonZeroLength() external {
        uint256 numSteps = 2;
        IStrategyBuilderModule.StrategyStep[] memory steps = new IStrategyBuilderModule.StrategyStep[](numSteps);

        uint32 strategyID = 222;
        vm.prank(address(account1));
        vm.expectRevert(abi.encodeWithSelector(IStrategyBuilderModule.NoConditionOrActions.selector, 0));
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);
    }

    //     /////////////////////////////////
    //     ////// deleteStrategy ///////////
    //     /////////////////////////////////

    function test_deleteStrategy_Success(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;
        vm.prank(address(account1));
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);

        //Act
        vm.startPrank(address(account1));
        IStrategyBuilderModule(address(account1)).deleteStrategy(strategyID);
        vm.stopPrank();

        //Assert
        assertTrue(strategyBuilderModule.strategy(address(account1), strategyID).creator == address(0));
        assertTrue(strategyBuilderModule.strategy(address(account1), strategyID).steps.length == 0);
    }

    function test_deleteStrategy_Success_StrategyWithConditions(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategyStepsWithCondition(numSteps);
        uint32 strategyID = 222;
        vm.prank(address(account1));
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);
        //Act
        vm.startPrank(address(account1));
        IStrategyBuilderModule(address(account1)).deleteStrategy(strategyID);
        vm.stopPrank();
        //Assert
        assertTrue(strategyBuilderModule.strategy(address(account1), strategyID).creator == address(0));
        assertTrue(strategyBuilderModule.strategy(address(account1), strategyID).steps.length == 0);
    }

    function test_deleteStrategy_Revert_StrategyInUse(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;
        vm.prank(address(account1));
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);

        //Mock FeeController and FeeHandler
        vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(true));
        vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(true));

        vm.startPrank(address(account1));
        uint32 conditionId = 2222;
        mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
        IStrategyBuilderModule.Condition memory condition = IStrategyBuilderModule.Condition({
            conditionAddress: address(mockCondition),
            id: 2222,
            result0: 0,
            result1: 0
        });
        IStrategyBuilderModule(address(account1)).createAutomation(
            1, strategyID, address(0), type(uint256).max, condition
        );
        vm.stopPrank();

        //Act

        vm.expectRevert(IStrategyBuilderModule.StrategyIsInUse.selector);
        vm.prank(address(account1));
        IStrategyBuilderModule(address(account1)).deleteStrategy(strategyID);
    }

    function test_deleteStrategy_Revert_StrategyDoesNotExist(uint32 strategyId) external {
        vm.expectRevert(IStrategyBuilderModule.StrategyDoesNotExist.selector);
        vm.prank(address(account1));
        IStrategyBuilderModule(address(account1)).deleteStrategy(strategyId); // Strategy ID doesn't exist
    }

    /////////////////////////////////
    ////// executeStrategy //////////
    /////////////////////////////////

    function test_executeStrategy_Success(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;

        deal(address(account1), 100 ether);

        //Mocks
        vm.mockCall(
            feeController,
            abi.encodeWithSelector(IFeeController.getTokenForAction.selector),
            abi.encode(address(0), false)
        );

        vm.mockCall(
            feeController,
            abi.encodeWithSelector(IFeeController.functionFeeConfig.selector),
            abi.encode(IFeeController.FeeConfig({feeType: IFeeController.FeeType.Deposit, feePercentage: 0}))
        );
        vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.minFeeInUSD.selector), abi.encode(0));

        //Act
        vm.startPrank(address(account1));
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);

        IStrategyBuilderModule(address(account1)).executeStrategy(strategyID);
        vm.stopPrank();

        //Assert
        assertEq(tokenReceiver.balance, numSteps * 2 * TOKEN_SEND_AMOUNT);
    }

    function test_executeStrategy_Success_StrategyWithMultiExecutionAction(uint256 _value) external {
        uint256 value = bound(_value, 1 ether, 10 ether);
        address[] memory receivers = new address[](2);
        address receiver1 = makeAddr("receiver1");
        address receiver2 = makeAddr("receiver2");
        receivers[0] = receiver1;
        receivers[1] = receiver2;
        vm.prank(address(account1));
        Token token = new Token("TestToken", "TT", 100 ether);
        IStrategyBuilderModule.StrategyStep[] memory steps =
            _createStrategyStepWithMultiExecutionAction(1, receivers, value, address(token));
        uint32 strategyID = 222;

        deal(address(account1), 100 ether);

        //Mocks
        vm.mockCall(
            feeController,
            abi.encodeWithSelector(IFeeController.getTokenForAction.selector),
            abi.encode(address(token), true)
        );

        uint256 feePerTarget = 10 * value / 100;
        vm.mockCall(
            feeController, abi.encodeWithSelector(IFeeController.calculateFee.selector), abi.encode(feePerTarget)
        );

        vm.mockCall(
            feeController,
            abi.encodeWithSelector(IFeeController.functionFeeConfig.selector),
            abi.encode(IFeeController.FeeConfig({feeType: IFeeController.FeeType.Deposit, feePercentage: 0}))
        );
        vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.minFeeInUSD.selector), abi.encode(0));
        vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(true));

        //Act
        vm.startPrank(address(account1));
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);

        IStrategyBuilderModule(address(account1)).executeStrategy(strategyID);
        vm.stopPrank();

        //Assert
        assertTrue(token.balanceOf(receiver1) == 2 * value);
        assertTrue(token.balanceOf(receiver2) == 2 * value);
    }

    function test_executeStrategy_OOB_RevertWithValidiationError() external {
        uint256 numSteps = 2;
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        steps[0].condition.result0 = 2;
        steps[0].condition.result1 = 2;
        uint32 strategyID = 222;
        deal(address(account1), 100 ether);
        //Mocks
        vm.mockCall(
            feeController,
            abi.encodeWithSelector(IFeeController.getTokenForAction.selector),
            abi.encode(address(0), false)
        );
        vm.mockCall(
            feeController,
            abi.encodeWithSelector(IFeeController.functionFeeConfig.selector),
            abi.encode(IFeeController.FeeConfig({feeType: IFeeController.FeeType.Deposit, feePercentage: 0}))
        );
        vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.minFeeInUSD.selector), abi.encode(0));
        //Act
        vm.startPrank(address(account1));
        vm.expectRevert(IStrategyBuilderModule.InvalidNextStepIndex.selector);

        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);

        vm.stopPrank();
    }

    /////////////////////////////////
    ////// createAutomation /////////
    /////////////////////////////////

    function test_createAutomation_Success(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;
        vm.prank(address(account1));
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);

        //Mock FeeController and FeeHandler
        vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(true));
        vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(true));

        vm.startPrank(address(account1));
        uint32 conditionId = 2222;
        mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
        IStrategyBuilderModule.Condition memory condition = IStrategyBuilderModule.Condition({
            conditionAddress: address(mockCondition),
            id: 2222,
            result0: 0,
            result1: 0
        });
        IStrategyBuilderModule(address(account1)).createAutomation(
            1, strategyID, address(0), type(uint256).max, condition
        );
        vm.stopPrank();

        //assert

        IStrategyBuilderModule.Automation memory automation = strategyBuilderModule.automation(address(account1), 1);
        assertEq(automation.strategyId, strategyID);
        assertEq(automation.condition.conditionAddress, address(mockCondition));
        assertEq(automation.condition.id, conditionId);
    }

    function test_createAutomation_Revert_InvalidPaymentToken_NotAllowed(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;
        vm.prank(address(account1));
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);

        //Mock FeeController and FeeHandler
        vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(true));
        vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(false));

        address paymentToken = makeAddr("invalid-token");

        vm.startPrank(address(account1));
        uint32 conditionId = 2222;
        mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
        IStrategyBuilderModule.Condition memory condition = IStrategyBuilderModule.Condition({
            conditionAddress: address(mockCondition),
            id: 2222,
            result0: 0,
            result1: 0
        });
        vm.expectRevert(IStrategyBuilderModule.PaymentTokenNotAllowed.selector);
        IStrategyBuilderModule(address(account1)).createAutomation(
            1, strategyID, paymentToken, type(uint256).max, condition
        );
        vm.stopPrank();
    }

    function test_createAutomation_Revert_InvalidPaymentToken_NotOracle(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyBuilderModule.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;
        vm.prank(address(account1));
        IStrategyBuilderModule(address(account1)).createStrategy(strategyID, creator, steps);

        //Mock FeeController and FeeHandler
        vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(false));
        vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(true));

        address paymentToken = makeAddr("invalid-token");

        vm.startPrank(address(account1));
        uint32 conditionId = 2222;
        mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
        IStrategyBuilderModule.Condition memory condition = IStrategyBuilderModule.Condition({
            conditionAddress: address(mockCondition),
            id: 2222,
            result0: 0,
            result1: 0
        });
        vm.expectRevert(IStrategyBuilderModule.PaymentTokenNotAllowed.selector);
        IStrategyBuilderModule(address(account1)).createAutomation(
            1, strategyID, paymentToken, type(uint256).max, condition
        );
        vm.stopPrank();
    }

    function _createStrategySteps(uint256 numSteps)
        internal
        view
        returns (StrategyBuilderModule.StrategyStep[] memory)
    {
        StrategyBuilderModule.StrategyStep[] memory steps = new StrategyBuilderModule.StrategyStep[](numSteps);

        for (uint256 i = 0; i < numSteps; i++) {
            StrategyBuilderModule.Condition memory condition = IStrategyBuilderModule.Condition({
                conditionAddress: address(0),
                id: 0,
                result0: i == numSteps - 1 ? 0 : uint8(i),
                result1: i == numSteps - 1 ? 0 : uint8(i + 1)
            });

            StrategyBuilderModule.Action[] memory actions = new StrategyBuilderModule.Action[](2);

            actions[0] = IStrategyBuilderModule.Action({
                target: tokenReceiver,
                parameter: "",
                value: TOKEN_SEND_AMOUNT,
                selector: bytes4(0),
                actionType: IStrategyBuilderModule.ActionType.EXTERNAL,
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
                target: tokenReceiver,
                parameter: "",
                value: TOKEN_SEND_AMOUNT,
                selector: bytes4(0),
                actionType: IStrategyBuilderModule.ActionType.EXTERNAL,
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

            steps[i] = IStrategyBuilderModule.StrategyStep({condition: condition, actions: actions});
        }

        return steps;
    }

    function _createStrategyStepsWithCondition(uint256 numSteps)
        internal
        returns (IStrategyBuilderModule.StrategyStep[] memory)
    {
        IStrategyBuilderModule.StrategyStep[] memory steps = new IStrategyBuilderModule.StrategyStep[](numSteps);
        for (uint256 i = 0; i < numSteps; i++) {
            IStrategyBuilderModule.Condition memory condition = IStrategyBuilderModule.Condition({
                conditionAddress: address(mockCondition),
                id: uint32(i + 1),
                result0: 0,
                result1: i == numSteps - 1 ? 0 : uint8(i + 1)
            });

            vm.prank(address(account1));
            MockCondition.Condition memory _mockCondition =
                MockCondition.Condition({result: true, active: true, updateable: true});
            mockCondition.addCondition(uint32(i + 1), _mockCondition);

            IStrategyBuilderModule.Action[] memory actions = new IStrategyBuilderModule.Action[](2);

            actions[0] = IStrategyBuilderModule.Action({
                target: tokenReceiver,
                parameter: "",
                value: TOKEN_SEND_AMOUNT,
                selector: bytes4(0),
                actionType: IStrategyBuilderModule.ActionType.EXTERNAL,
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
                target: tokenReceiver,
                parameter: "",
                value: TOKEN_SEND_AMOUNT,
                selector: bytes4(0),
                actionType: IStrategyBuilderModule.ActionType.EXTERNAL,
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

            steps[i] = IStrategyBuilderModule.StrategyStep({condition: condition, actions: actions});
        }

        return steps;
    }

    function _createStrategyStepsWithSameCondition(uint256 numSteps, uint32 conditionId)
        internal
        returns (IStrategyBuilderModule.StrategyStep[] memory)
    {
        vm.prank(address(account1));
        MockCondition.Condition memory _mockCondition =
            MockCondition.Condition({result: true, active: true, updateable: true});
        mockCondition.addCondition(conditionId, _mockCondition);

        IStrategyBuilderModule.StrategyStep[] memory steps = new IStrategyBuilderModule.StrategyStep[](numSteps);
        for (uint256 i = 0; i < numSteps; i++) {
            IStrategyBuilderModule.Condition memory condition = IStrategyBuilderModule.Condition({
                conditionAddress: address(mockCondition),
                id: conditionId,
                result0: 0,
                result1: i == numSteps - 1 ? 0 : uint8(i + 1)
            });

            IStrategyBuilderModule.Action[] memory actions = new IStrategyBuilderModule.Action[](2);

            actions[0] = IStrategyBuilderModule.Action({
                target: tokenReceiver,
                parameter: "",
                value: TOKEN_SEND_AMOUNT,
                selector: bytes4(0),
                actionType: IStrategyBuilderModule.ActionType.EXTERNAL,
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
                target: tokenReceiver,
                parameter: "",
                value: TOKEN_SEND_AMOUNT,
                selector: bytes4(0),
                actionType: IStrategyBuilderModule.ActionType.EXTERNAL,
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

            steps[i] = IStrategyBuilderModule.StrategyStep({condition: condition, actions: actions});
        }

        return steps;
    }

    function _createStrategyStepWithMultiExecutionAction(
        uint32 conditionId,
        address[] memory receivers,
        uint256 value,
        address token
    ) internal returns (IStrategyBuilderModule.StrategyStep[] memory) {
        vm.prank(address(account1));
        MockCondition.Condition memory _mockCondition =
            MockCondition.Condition({result: true, active: true, updateable: true});
        mockCondition.addCondition(conditionId, _mockCondition);

        IStrategyBuilderModule.StrategyStep[] memory steps = new IStrategyBuilderModule.StrategyStep[](1);

        IStrategyBuilderModule.Condition memory condition = IStrategyBuilderModule.Condition({
            conditionAddress: address(mockCondition),
            id: conditionId,
            result0: 0,
            result1: 0
        });

        IStrategyBuilderModule.Action[] memory actions = new IStrategyBuilderModule.Action[](2);

        MockAction actionContract = new MockAction();

        actions[0] = IStrategyBuilderModule.Action({
            target: address(actionContract),
            parameter: abi.encode(receivers, address(token), value),
            value: 0,
            selector: MockAction.execute.selector,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: new IStrategyBuilderModule.ContextKey[](0), // Empty array
            output: IStrategyBuilderModule.ContextKey({ // Empty struct
                key: "REPLACEMENT_VALUE",
                parameterReplacement: IStrategyBuilderModule.Parameter({
                    offset: 0,
                    length: 32,
                    paramType: IStrategyBuilderModule.ParamType.UINT256
                })
            }),
            result: 0
        });

        IStrategyBuilderModule.ContextKey[] memory inputs = new IStrategyBuilderModule.ContextKey[](1);
        inputs[0] = IStrategyBuilderModule.ContextKey({
            key: "REPLACEMENT_VALUE",
            parameterReplacement: IStrategyBuilderModule.Parameter({
                offset: 64, // This is where 'value' is located
                length: 32, // uint256 is 32 bytes
                paramType: IStrategyBuilderModule.ParamType.UINT256
            })
        });
        actions[1] = IStrategyBuilderModule.Action({
            target: address(actionContract),
            parameter: abi.encode(receivers, address(token), uint256(0)),
            value: 0,
            selector: MockAction.execute.selector,
            actionType: IStrategyBuilderModule.ActionType.INTERNAL_ACTION,
            inputs: inputs,
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

        steps[0] = IStrategyBuilderModule.StrategyStep({condition: condition, actions: actions});

        return steps;
    }
}

// contract StrategyBuilderPluginTest is Test {
//     //Modular Account
//     IEntryPoint entryPoint;
//     UpgradeableModularAccount account1;
//     address owner1;
//     uint256 owner1Key;

//     // StrategyBuilderPlugin
//     StrategyBuilderPlugin strategyBuilderPlugin;

//     //Mocks
//     MockCondition mockCondition = new MockCondition();

//     address feeHandler = makeAddr("feeHandler");
//     address feeController = makeAddr("feeController");
//     address actionRegistry = makeAddr("actionRegistry");
//     address automationExecutor = makeAddr("automationExecutor");
//     address beneficiary = makeAddr("beneficiary");
//     address creator = makeAddr("creator");
//     address tokenReceiver = makeAddr("tokenReceiver");

//     uint256 constant TOKEN_SEND_AMOUNT = 1 ether;

//     function setUp() public {
//         // we'll be using the entry point so we can send a user operation through
//         // in this case our plugin only accepts calls to increment via user operations so this is essential
//         entryPoint = IEntryPoint(address(new EntryPoint()));

//         // our modular smart contract account will be installed with the single owner plugin
//         // so we have a way to determine who is authorized to do things on this account
//         // we'll use this plugin's validation for our increment function
//         SingleOwnerPlugin singleOwnerPlugin = new SingleOwnerPlugin();
//         MSCAFactoryFixture factory = new MSCAFactoryFixture(entryPoint, singleOwnerPlugin);

//         // create a single owner for this account and provide the address to our modular account
//         // we'll also add ether to our account to pay for gas fees
//         (owner1, owner1Key) = makeAddrAndKey("owner1");
//         account1 = UpgradeableModularAccount(payable(factory.createAccount(owner1, 0)));
//         vm.deal(address(account1), 100 ether);

//         strategyBuilderPlugin = new StrategyBuilderPlugin(feeController, feeHandler, actionRegistry);
//         bytes32 manifestHash = keccak256(abi.encode(strategyBuilderPlugin.pluginManifest()));

//         // we will have a single function dependency for our counter contract: the single owner user op validation
//         // we'll use this to ensure that only an owner can sign a user operation that can successfully increment
//         FunctionReference[] memory dependencies = new FunctionReference[](1);
//         dependencies[0] = FunctionReferenceLib.pack(
//             address(singleOwnerPlugin), uint8(ISingleOwnerPlugin.FunctionId.USER_OP_VALIDATION_OWNER)
//         );

//         // install this plugin on the account as the owner
//         vm.prank(owner1);
//         account1.installPlugin({
//             plugin: address(strategyBuilderPlugin),
//             manifestHash: manifestHash,
//             pluginInstallData: "0x",
//             dependencies: dependencies
//         });
//     }

//     ////////////////////////////////
//     ////// createStrategy //////////
//     ////////////////////////////////

//     function test_createStrategy_Success(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);

//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         //Assert
//         IStrategyBuilderPlugin.Strategy memory strategy = strategyBuilderPlugin.strategy(address(account1), strategyID);

//         assertEq(strategy.creator, creator);
//         assertEq(strategy.steps.length, numSteps);
//     }

//     function test_createStrategy_Revert_AlreadyExists(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         vm.expectRevert(IStrategyBuilderPlugin.StrategyAlreadyExist.selector);
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);
//     }

//     function test_createStrategy_Success_StepsWithCondition(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategyStepsWithCondition(numSteps);

//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         //Assert
//         IStrategyBuilderPlugin.Strategy memory strategy = strategyBuilderPlugin.strategy(address(account1), strategyID);

//         assertEq(strategy.creator, creator);
//         assertEq(strategy.steps.length, numSteps);

//         assertTrue(mockCondition.strategies(address(account1), uint32(1)).length > 0);
//     }

//     function test_createStrategy_Success_SameConditionMultipleTimesInStrategy(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);

//         uint32 conditionId = 22;
//         IStrategyBuilderPlugin.StrategyStep[] memory steps =
//             _createStrategyStepsWithSameCondition(numSteps, conditionId);

//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         //Assert
//         IStrategyBuilderPlugin.Strategy memory strategy = strategyBuilderPlugin.strategy(address(account1), strategyID);
//         assertEq(strategy.creator, creator);
//         assertEq(strategy.steps.length, numSteps);
//         assertTrue(mockCondition.strategies(address(account1), conditionId).length > 0);
//         assertTrue(mockCondition.conditionInStrategy(address(account1), conditionId, strategyID));
//     }

//     function test_createStrategy_Revert_InvalidNextStepId(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategyStepsWithCondition(numSteps);

//         steps[steps.length - 1].condition.result1 = 100; // Invalid next step ID

//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         vm.expectRevert(IStrategyBuilderPlugin.InvalidNextStepIndex.selector);
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);
//     }

//     function test_createStrategy_Revert_InvalidAction_NoContract(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);

//         address invalidAction = makeAddr("invalid-address");
//         steps[0].actions[0].target = invalidAction;
//         steps[0].actions[0].actionType = IStrategyBuilderPlugin.ActionType.INTERNAL_ACTION;

//         vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(true));

//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         vm.expectRevert(IStrategyBuilderPlugin.InvalidActionTarget.selector);
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);
//     }

//     function test_createStrategy_Revert_InvalidAction_NoInterface(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);

//         Token invalidActionContract = new Token("Test", "TST", 1 ether);
//         address invalidAction = address(invalidActionContract);
//         steps[0].actions[0].target = invalidAction;
//         steps[0].actions[0].actionType = IStrategyBuilderPlugin.ActionType.INTERNAL_ACTION;

//         vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(true));

//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         vm.expectRevert(IStrategyBuilderPlugin.InvalidActionTarget.selector);
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);
//     }

//     function test_createStrategy_Revert_InvalidAction_IncorrectInterface(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);

//         WrongInterfaceContract invalidActionContract = new WrongInterfaceContract();
//         address invalidAction = address(invalidActionContract);
//         steps[0].actions[0].target = invalidAction;
//         steps[0].actions[0].actionType = IStrategyBuilderPlugin.ActionType.INTERNAL_ACTION;

//         vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(true));

//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         vm.expectRevert(IStrategyBuilderPlugin.InvalidActionTarget.selector);
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);
//     }

//     function test_createStrategy_Revert_InvalidAction_ZeroAddress(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);

//         address invalidAction = address(0);
//         steps[0].actions[0].target = invalidAction;
//         steps[0].actions[0].actionType = IStrategyBuilderPlugin.ActionType.EXTERNAL;

//         vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(true));

//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         vm.expectRevert(IStrategyBuilderPlugin.InvalidActionTarget.selector);
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);
//     }

//     function test_createStrategy_Revert_InvalidAction_NotRegistered(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);

//         address invalidAction = makeAddr("not-regisstered");
//         steps[0].actions[0].target = invalidAction;
//         steps[0].actions[0].actionType = IStrategyBuilderPlugin.ActionType.INTERNAL_ACTION;

//         vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(false));

//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         vm.expectRevert(IStrategyBuilderPlugin.InvalidActionTarget.selector);
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);
//     }

//     function test_createStrategy_Revert_InvalidCondition_NoInterface(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);

//         Token invalidConditionContract = new Token("test", "TST", 1 ether);
//         steps[0].condition.conditionAddress = address(invalidConditionContract);

//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         vm.expectRevert(IStrategyBuilderPlugin.InvalidCondition.selector);
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);
//     }

//     function test_createStrategy_Revert_InvalidCondition_IncorrectInterface(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);

//         WrongInterfaceContract invalidConditionContract = new WrongInterfaceContract();
//         steps[0].condition.conditionAddress = address(invalidConditionContract);

//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         vm.expectRevert(IStrategyBuilderPlugin.InvalidCondition.selector);
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);
//     }

//     function test_createStrategy_Revert_InvalidCondition_NoContract(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);

//         steps[0].condition.conditionAddress = makeAddr("no-contract-address");

//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         vm.expectRevert(IStrategyBuilderPlugin.InvalidConditionAddress.selector);
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);
//     }

//     function test_createStrategy_Empty() external {
//         uint256 numSteps;
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         vm.expectRevert(IStrategyBuilderPlugin.InvalidStepArrayLength.selector);

//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);
//     }

//     function test_createStrategy_EmptyNonZeroLength() external {
//         uint256 numSteps = 2;
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = new IStrategyBuilderPlugin.StrategyStep[](numSteps);

//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         vm.expectRevert(abi.encodeWithSelector(IStrategyBuilderPlugin.NoConditionOrActions.selector, 0));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);
//     }

//     /////////////////////////////////
//     ////// deleteStrategy ///////////
//     /////////////////////////////////

//     function test_deleteStrategy_Success(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         //Act
//         vm.startPrank(address(account1));
//         strategyBuilderPlugin.deleteStrategy(strategyID);
//         vm.stopPrank();

//         //Assert
//         assertTrue(strategyBuilderPlugin.strategy(address(account1), strategyID).creator == address(0));
//         assertTrue(strategyBuilderPlugin.strategy(address(account1), strategyID).steps.length == 0);
//     }

//     function test_deleteStrategy_Success_StrategyWithConditions(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategyStepsWithCondition(numSteps);
//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);
//         //Act
//         vm.startPrank(address(account1));
//         strategyBuilderPlugin.deleteStrategy(strategyID);
//         vm.stopPrank();
//         //Assert
//         assertTrue(strategyBuilderPlugin.strategy(address(account1), strategyID).creator == address(0));
//         assertTrue(strategyBuilderPlugin.strategy(address(account1), strategyID).steps.length == 0);
//     }

//     function test_deleteStrategy_Revert_StrategyInUse(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         //Mock FeeController and FeeHandler
//         vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(true));
//         vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(true));

//         vm.startPrank(address(account1));
//         uint32 conditionId = 2222;
//         mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
//         IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//             conditionAddress: address(mockCondition),
//             id: 2222,
//             result0: 0,
//             result1: 0
//         });
//         strategyBuilderPlugin.createAutomation(1, strategyID, address(0), type(uint256).max, condition);
//         vm.stopPrank();

//         //Act

//         vm.expectRevert(IStrategyBuilderPlugin.StrategyIsInUse.selector);
//         vm.prank(address(account1));
//         strategyBuilderPlugin.deleteStrategy(strategyID);
//     }

//     function test_deleteStrategy_Revert_StrategyDoesNotExist(uint32 strategyId) external {
//         vm.expectRevert(IStrategyBuilderPlugin.StrategyDoesNotExist.selector);
//         vm.prank(address(account1));
//         strategyBuilderPlugin.deleteStrategy(strategyId); // Strategy ID doesn't exist
//     }

//     /////////////////////////////////
//     ////// executeStrategy //////////
//     /////////////////////////////////

//     function test_executeStrategy_Success(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         uint32 strategyID = 222;

//         deal(address(account1), 100 ether);

//         //Mocks
//         vm.mockCall(
//             feeController,
//             abi.encodeWithSelector(IFeeController.getTokenForAction.selector),
//             abi.encode(address(0), false)
//         );

//         vm.mockCall(
//             feeController,
//             abi.encodeWithSelector(IFeeController.functionFeeConfig.selector),
//             abi.encode(IFeeController.FeeConfig({feeType: IFeeController.FeeType.Deposit, feePercentage: 0}))
//         );
//         vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.minFeeInUSD.selector), abi.encode(0));

//         //Act
//         vm.startPrank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         strategyBuilderPlugin.executeStrategy(strategyID);
//         vm.stopPrank();

//         //Assert
//         assertEq(tokenReceiver.balance, numSteps * 2 * TOKEN_SEND_AMOUNT);
//     }

//     function test_executeStrategy_Success_StrategyWithMultiExecutionAction(uint256 _value) external {
//         uint256 value = bound(_value, 1 ether, 10 ether);
//         address[] memory receivers = new address[](2);
//         address receiver1 = makeAddr("receiver1");
//         address receiver2 = makeAddr("receiver2");
//         receivers[0] = receiver1;
//         receivers[1] = receiver2;
//         vm.prank(address(account1));
//         Token token = new Token("TestToken", "TT", 100 ether);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps =
//             _createStrategyStepWithMultiExecutionAction(1, receivers, value, address(token));
//         uint32 strategyID = 222;

//         deal(address(account1), 100 ether);

//         //Mocks
//         vm.mockCall(
//             feeController,
//             abi.encodeWithSelector(IFeeController.getTokenForAction.selector),
//             abi.encode(address(token), true)
//         );

//         uint256 feePerTarget = 10 * value / 100;
//         vm.mockCall(
//             feeController, abi.encodeWithSelector(IFeeController.calculateFee.selector), abi.encode(feePerTarget)
//         );

//         vm.mockCall(
//             feeController,
//             abi.encodeWithSelector(IFeeController.functionFeeConfig.selector),
//             abi.encode(IFeeController.FeeConfig({feeType: IFeeController.FeeType.Deposit, feePercentage: 0}))
//         );
//         vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.minFeeInUSD.selector), abi.encode(0));
//         vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(true));

//         //Act
//         vm.startPrank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         strategyBuilderPlugin.executeStrategy(strategyID);
//         vm.stopPrank();

//         //Assert
//         assertTrue(token.balanceOf(receiver1) == value);
//         assertTrue(token.balanceOf(receiver2) == value);
//     }

//     function test_executeStrategy_OOB_RevertWithValidiationError() external {
//         uint256 numSteps = 2;
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         steps[0].condition.result0 = 2;
//         steps[0].condition.result1 = 2;
//         uint32 strategyID = 222;
//         deal(address(account1), 100 ether);
//         //Mocks
//         vm.mockCall(
//             feeController,
//             abi.encodeWithSelector(IFeeController.getTokenForAction.selector),
//             abi.encode(address(0), false)
//         );
//         vm.mockCall(
//             feeController,
//             abi.encodeWithSelector(IFeeController.functionFeeConfig.selector),
//             abi.encode(IFeeController.FeeConfig({feeType: IFeeController.FeeType.Deposit, feePercentage: 0}))
//         );
//         vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.minFeeInUSD.selector), abi.encode(0));
//         //Act
//         vm.startPrank(address(account1));
//         vm.expectRevert(IStrategyBuilderPlugin.InvalidNextStepIndex.selector);

//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         vm.stopPrank();
//     }

//     /////////////////////////////////
//     ////// createAutomation /////////
//     /////////////////////////////////

//     function test_createAutomation_Success(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         //Mock FeeController and FeeHandler
//         vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(true));
//         vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(true));

//         vm.startPrank(address(account1));
//         uint32 conditionId = 2222;
//         mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
//         IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//             conditionAddress: address(mockCondition),
//             id: 2222,
//             result0: 0,
//             result1: 0
//         });
//         strategyBuilderPlugin.createAutomation(1, strategyID, address(0), type(uint256).max, condition);
//         vm.stopPrank();

//         //assert

//         IStrategyBuilderPlugin.Automation memory automation = strategyBuilderPlugin.automation(address(account1), 1);
//         assertEq(automation.strategyId, strategyID);
//         assertEq(automation.condition.conditionAddress, address(mockCondition));
//         assertEq(automation.condition.id, conditionId);
//     }

//     function test_createAutomation_Revert_InvalidPaymentToken_NotAllowed(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         //Mock FeeController and FeeHandler
//         vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(true));
//         vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(false));

//         address paymentToken = makeAddr("invalid-token");

//         vm.startPrank(address(account1));
//         uint32 conditionId = 2222;
//         mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
//         IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//             conditionAddress: address(mockCondition),
//             id: 2222,
//             result0: 0,
//             result1: 0
//         });
//         vm.expectRevert(IStrategyBuilderPlugin.PaymentTokenNotAllowed.selector);
//         strategyBuilderPlugin.createAutomation(1, strategyID, paymentToken, type(uint256).max, condition);
//         vm.stopPrank();
//     }

//     function test_createAutomation_Revert_InvalidPaymentToken_NotOracle(uint8 _numSteps) external {
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         //Mock FeeController and FeeHandler
//         vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(false));
//         vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(true));

//         address paymentToken = makeAddr("invalid-token");

//         vm.startPrank(address(account1));
//         uint32 conditionId = 2222;
//         mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
//         IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//             conditionAddress: address(mockCondition),
//             id: 2222,
//             result0: 0,
//             result1: 0
//         });
//         vm.expectRevert(IStrategyBuilderPlugin.PaymentTokenNotAllowed.selector);
//         strategyBuilderPlugin.createAutomation(1, strategyID, paymentToken, type(uint256).max, condition);
//         vm.stopPrank();
//     }

//     ////////////////////////////////
//     ////// deleteAutomation ////////
//     ////////////////////////////////

//     function test_deleteAutomation_Success(uint8 _numSteps) external {
//         uint32 automationId = 1;
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         //Mock FeeController and FeeHandler
//         vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(true));
//         vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(true));

//         vm.startPrank(address(account1));
//         uint32 conditionId = 2222;
//         mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
//         IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//             conditionAddress: address(mockCondition),
//             id: 2222,
//             result0: 0,
//             result1: 0
//         });
//         strategyBuilderPlugin.createAutomation(automationId, strategyID, address(0), type(uint256).max, condition);
//         vm.stopPrank();

//         //Act
//         vm.prank(address(account1));
//         strategyBuilderPlugin.deleteAutomation(automationId);

//         //assert

//         IStrategyBuilderPlugin.Automation memory automation = strategyBuilderPlugin.automation(address(account1), 1);
//         assertEq(automation.strategyId, 0);
//         assertEq(automation.condition.conditionAddress, address(0));
//         assertEq(automation.condition.id, 0);
//     }

//     function test_deleteAutomation_Success_MultipleAutomationsActive(uint8 _numSteps) external {
//         uint32 automationId = 1;
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         //Mock FeeController and FeeHandler
//         vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(true));
//         vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(true));

//         vm.startPrank(address(account1));
//         uint32 conditionId = 2222;
//         mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
//         IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//             conditionAddress: address(mockCondition),
//             id: 2222,
//             result0: 0,
//             result1: 0
//         });
//         strategyBuilderPlugin.createAutomation(automationId, strategyID, address(0), type(uint256).max, condition);
//         vm.stopPrank();

//         //Duplicate the automation
//         uint32 automationId2 = 2;
//         vm.startPrank(address(account1));
//         strategyBuilderPlugin.createAutomation(automationId2, strategyID, address(0), type(uint256).max, condition);
//         vm.stopPrank();

//         //Act

//         //Delete the first the first automation and then the second
//         vm.prank(address(account1));
//         strategyBuilderPlugin.deleteAutomation(automationId);

//         vm.prank(address(account1));
//         strategyBuilderPlugin.deleteAutomation(automationId2);
//     }

//     ////////////////////////////////
//     ////// executeAutomation ////////
//     ////////////////////////////////

//     function test_executeAutomation_Success(uint8 _numSteps) external {
//         uint32 automationId = 1;
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         // Mock Fee setup
//         _mockFeeSetup();

//         vm.startPrank(address(account1));
//         uint32 conditionId = 2222;
//         mockCondition.addCondition(
//             conditionId, MockCondition.Condition({result: true, active: true, updateable: false})
//         );
//         IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//             conditionAddress: address(mockCondition),
//             id: 2222,
//             result0: 0,
//             result1: 0
//         });
//         strategyBuilderPlugin.createAutomation(automationId, strategyID, address(0), type(uint256).max, condition);
//         vm.stopPrank();

//         address executer = makeAddr("executer");
//         vm.prank(executer);
//         strategyBuilderPlugin.executeAutomation(automationId, address(account1), executer);

//         //assert

//         assertEq(tokenReceiver.balance, numSteps * 2 * TOKEN_SEND_AMOUNT);
//     }

//     function test_executeAutomation_UpdateAutomationCondition_Success(uint8 _numSteps) external {
//         uint32 automationId = 1;
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         // Mock Fee setup
//         _mockFeeSetup();

//         vm.startPrank(address(account1));
//         uint32 conditionId = 2222;
//         mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
//         IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//             conditionAddress: address(mockCondition),
//             id: 2222,
//             result0: 0,
//             result1: 0
//         });
//         strategyBuilderPlugin.createAutomation(automationId, strategyID, address(0), type(uint256).max, condition);
//         vm.stopPrank();

//         address executer = makeAddr("executer");
//         vm.prank(executer);
//         strategyBuilderPlugin.executeAutomation(automationId, address(account1), executer);

//         //assert

//         assertEq(tokenReceiver.balance, numSteps * 2 * TOKEN_SEND_AMOUNT);
//     }

//     function test_executeAutomation_UpdateAutomationCondition_Revert(uint8 _numSteps) external {
//         uint32 automationId = 1;
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         // Mock Fee setup
//         _mockFeeSetup();

//         vm.startPrank(address(account1));
//         uint32 conditionId = 2222;
//         mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
//         IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//             conditionAddress: address(mockCondition),
//             id: 2222,
//             result0: 0,
//             result1: 0
//         });
//         strategyBuilderPlugin.createAutomation(automationId, strategyID, address(0), type(uint256).max, condition);
//         vm.stopPrank();

//         vm.mockCall(
//             address(mockCondition), abi.encodeWithSelector(MockCondition.updateCondition.selector), abi.encode(false)
//         );

//         address executer = makeAddr("executer");
//         vm.prank(executer);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IStrategyBuilderPlugin.UpdateConditionFailed.selector, address(mockCondition), conditionId
//             )
//         );
//         strategyBuilderPlugin.executeAutomation(automationId, address(account1), executer);
//     }

//     function test_executeAutomation_PaymentERC20Token_Success(uint8 _numSteps) external {
//         uint32 automationId = 1;
//         uint256 numSteps = bound(_numSteps, 1, 10);
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(numSteps);
//         uint32 strategyID = 222;
//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         // Mock Fee setup
//         _mockFeeSetup();

//         vm.prank(address(account1));
//         Token paymentToken = new Token("TestToken", "TT", 100 ether);

//         vm.startPrank(address(account1));
//         uint32 conditionId = 2222;
//         mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
//         IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//             conditionAddress: address(mockCondition),
//             id: 2222,
//             result0: 0,
//             result1: 0
//         });
//         strategyBuilderPlugin.createAutomation(
//             automationId, strategyID, address(paymentToken), type(uint256).max, condition
//         );
//         vm.stopPrank();

//         address executer = makeAddr("executer");
//         vm.prank(executer);
//         strategyBuilderPlugin.executeAutomation(automationId, address(account1), executer);
//     }

//     function test_executeAutomation_Revert_AutomationNotExecutable() external {
//         uint32 automationId = 1;
//         uint32 strategyID = 222;
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(1);

//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         // Mock Fee setup
//         _mockFeeSetup();

//         // Add a condition that returns `false`
//         vm.startPrank(address(account1));
//         uint32 conditionId = 3333;
//         mockCondition.addCondition(
//             conditionId, MockCondition.Condition({result: false, active: true, updateable: true})
//         );

//         IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//             conditionAddress: address(mockCondition),
//             id: conditionId,
//             result0: 0,
//             result1: 0
//         });

//         strategyBuilderPlugin.createAutomation(automationId, strategyID, address(0), type(uint256).max, condition);
//         vm.stopPrank();

//         address executer = makeAddr("executer");
//         vm.prank(executer);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IStrategyBuilderPlugin.AutomationNotExecutable.selector, address(mockCondition), conditionId
//             )
//         );
//         strategyBuilderPlugin.executeAutomation(automationId, address(account1), executer);
//     }

//     function test_executeAutomation_Revert_FeeExceedMaxFee() external {
//         uint32 automationId = 1;
//         uint32 strategyID = 222;
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = _createStrategySteps(1);

//         vm.prank(address(account1));
//         strategyBuilderPlugin.createStrategy(strategyID, creator, steps);

//         // Mock FeeController to return a high fee
//         _mockFeeSetup();
//         vm.mockCall(
//             feeController,
//             abi.encodeWithSelector(IFeeController.calculateTokenAmount.selector),
//             abi.encode(1 ether) // too high
//         );

//         // Condition is valid
//         vm.startPrank(address(account1));
//         uint32 conditionId = 4444;
//         mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));

//         IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//             conditionAddress: address(mockCondition),
//             id: conditionId,
//             result0: 0,
//             result1: 0
//         });

//         strategyBuilderPlugin.createAutomation(automationId, strategyID, address(0), 0.0001 ether, condition); // maxFee = 0.0001 ether
//         vm.stopPrank();

//         address executer = makeAddr("executer");
//         vm.prank(executer);
//         vm.expectRevert(IStrategyBuilderPlugin.FeeExceedMaxFee.selector);
//         strategyBuilderPlugin.executeAutomation(automationId, address(account1), executer);
//     }

//     ////////////////////////
//     ////// HELPER //////////
//     ////////////////////////

//     function _mockFeeSetup() internal {
//         vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(true));
//         vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(true));
//         vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.handleFeeETH.selector), abi.encode(0.002 ether));
//         vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.handleFee.selector), abi.encode(0.002 ether));
//         vm.mockCall(
//             feeController,
//             abi.encodeWithSelector(IFeeController.getTokenForAction.selector),
//             abi.encode(address(0), false)
//         );
//         vm.mockCall(
//             feeController,
//             abi.encodeWithSelector(IFeeController.functionFeeConfig.selector),
//             abi.encode(IFeeController.FeeConfig({feeType: IFeeController.FeeType.Deposit, feePercentage: 0}))
//         );
//         vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.minFeeInUSD.selector), abi.encode(0.001 ether));
//         vm.mockCall(
//             feeController, abi.encodeWithSelector(IFeeController.calculateTokenAmount.selector), abi.encode(0.002 ether)
//         );
//     }

//     function _createStrategySteps(uint256 numSteps)
//         internal
//         view
//         returns (IStrategyBuilderPlugin.StrategyStep[] memory)
//     {
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = new IStrategyBuilderPlugin.StrategyStep[](numSteps);

//         for (uint256 i = 0; i < numSteps; i++) {
//             IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//                 conditionAddress: address(0),
//                 id: 0,
//                 result0: i == numSteps - 1 ? 0 : uint8(i),
//                 result1: i == numSteps - 1 ? 0 : uint8(i + 1)
//             });

//             IStrategyBuilderPlugin.Action[] memory actions = new IStrategyBuilderPlugin.Action[](2);

//             actions[0] = IStrategyBuilderPlugin.Action({
//                 target: tokenReceiver,
//                 parameter: "",
//                 value: TOKEN_SEND_AMOUNT,
//                 selector: bytes4(0),
//                 actionType: IStrategyBuilderPlugin.ActionType.EXTERNAL
//             });

//             actions[1] = IStrategyBuilderPlugin.Action({
//                 target: tokenReceiver,
//                 parameter: "",
//                 value: TOKEN_SEND_AMOUNT,
//                 selector: bytes4(0),
//                 actionType: IStrategyBuilderPlugin.ActionType.EXTERNAL
//             });

//             steps[i] = IStrategyBuilderPlugin.StrategyStep({condition: condition, actions: actions});
//         }

//         return steps;
//     }

//     function _createStrategyStepsWithCondition(uint256 numSteps)
//         internal
//         returns (IStrategyBuilderPlugin.StrategyStep[] memory)
//     {
//         IStrategyBuilderPlugin.StrategyStep[] memory steps = new IStrategyBuilderPlugin.StrategyStep[](numSteps);
//         for (uint256 i = 0; i < numSteps; i++) {
//             IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//                 conditionAddress: address(mockCondition),
//                 id: uint32(i + 1),
//                 result0: 0,
//                 result1: i == numSteps - 1 ? 0 : uint8(i + 1)
//             });

//             vm.prank(address(account1));
//             MockCondition.Condition memory _mockCondition =
//                 MockCondition.Condition({result: true, active: true, updateable: true});
//             mockCondition.addCondition(uint32(i + 1), _mockCondition);

//             IStrategyBuilderPlugin.Action[] memory actions = new IStrategyBuilderPlugin.Action[](2);

//             actions[0] = IStrategyBuilderPlugin.Action({
//                 target: tokenReceiver,
//                 parameter: "",
//                 value: TOKEN_SEND_AMOUNT,
//                 selector: bytes4(0),
//                 actionType: IStrategyBuilderPlugin.ActionType.EXTERNAL
//             });

//             actions[1] = IStrategyBuilderPlugin.Action({
//                 target: tokenReceiver,
//                 parameter: "",
//                 value: TOKEN_SEND_AMOUNT,
//                 selector: bytes4(0),
//                 actionType: IStrategyBuilderPlugin.ActionType.EXTERNAL
//             });

//             steps[i] = IStrategyBuilderPlugin.StrategyStep({condition: condition, actions: actions});
//         }

//         return steps;
//     }

//     function _createStrategyStepsWithSameCondition(uint256 numSteps, uint32 conditionId)
//         internal
//         returns (IStrategyBuilderPlugin.StrategyStep[] memory)
//     {
//         vm.prank(address(account1));
//         MockCondition.Condition memory _mockCondition =
//             MockCondition.Condition({result: true, active: true, updateable: true});
//         mockCondition.addCondition(conditionId, _mockCondition);

//         IStrategyBuilderPlugin.StrategyStep[] memory steps = new IStrategyBuilderPlugin.StrategyStep[](numSteps);
//         for (uint256 i = 0; i < numSteps; i++) {
//             IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//                 conditionAddress: address(mockCondition),
//                 id: conditionId,
//                 result0: 0,
//                 result1: i == numSteps - 1 ? 0 : uint8(i + 1)
//             });

//             IStrategyBuilderPlugin.Action[] memory actions = new IStrategyBuilderPlugin.Action[](2);

//             actions[0] = IStrategyBuilderPlugin.Action({
//                 target: tokenReceiver,
//                 parameter: "",
//                 value: TOKEN_SEND_AMOUNT,
//                 selector: bytes4(0),
//                 actionType: IStrategyBuilderPlugin.ActionType.EXTERNAL
//             });

//             actions[1] = IStrategyBuilderPlugin.Action({
//                 target: tokenReceiver,
//                 parameter: "",
//                 value: TOKEN_SEND_AMOUNT,
//                 selector: bytes4(0),
//                 actionType: IStrategyBuilderPlugin.ActionType.EXTERNAL
//             });

//             steps[i] = IStrategyBuilderPlugin.StrategyStep({condition: condition, actions: actions});
//         }

//         return steps;
//     }

//     function _createStrategyStepWithMultiExecutionAction(
//         uint32 conditionId,
//         address[] memory receivers,
//         uint256 value,
//         address token
//     ) internal returns (IStrategyBuilderPlugin.StrategyStep[] memory) {
//         vm.prank(address(account1));
//         MockCondition.Condition memory _mockCondition =
//             MockCondition.Condition({result: true, active: true, updateable: true});
//         mockCondition.addCondition(conditionId, _mockCondition);

//         IStrategyBuilderPlugin.StrategyStep[] memory steps = new IStrategyBuilderPlugin.StrategyStep[](1);

//         IStrategyBuilderPlugin.Condition memory condition = IStrategyBuilderPlugin.Condition({
//             conditionAddress: address(mockCondition),
//             id: conditionId,
//             result0: 0,
//             result1: 0
//         });

//         IStrategyBuilderPlugin.Action[] memory actions = new IStrategyBuilderPlugin.Action[](1);

//         MockAction actionContract = new MockAction();

//         actions[0] = IStrategyBuilderPlugin.Action({
//             target: address(actionContract),
//             parameter: abi.encode(receivers, address(token), value),
//             value: 0,
//             selector: MockAction.execute.selector,
//             actionType: IStrategyBuilderPlugin.ActionType.INTERNAL_ACTION
//         });

//         steps[0] = IStrategyBuilderPlugin.StrategyStep({condition: condition, actions: actions});

//         return steps;
//     }
// }
