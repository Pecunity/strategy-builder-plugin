// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {StrategyVaultFactory} from "contracts/StrategyVaultFactory.sol";
import {StrategyVault} from "contracts/StrategyVault.sol";
import {IStrategyVault} from "contracts/interfaces/IStrategyVault.sol";

import {IFeeController} from "contracts/interfaces/IFeeController.sol";
import {IFeeHandler} from "contracts/interfaces/IFeeHandler.sol";
import {IActionRegistry} from "contracts/interfaces/IActionRegistry.sol";
import {BaseCondition} from "contracts/condition/BaseCondition.sol";

import {MockCondition} from "contracts/test/mocks/MockCondition.sol";
import {Token} from "contracts/test/mocks/MockToken.sol";
import {WrongInterfaceContract} from "contracts/test/mocks/WrongInterfaceContract.sol";
import {MockAction} from "contracts/test/mocks/MockAction.sol";

contract StrategyVaultTest is Test {
    StrategyVaultFactory factory;
    StrategyVault vaultImplementation;

    address owner1;
    uint256 owner1Key;
    StrategyVault public vault1;

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
        (owner1, owner1Key) = makeAddrAndKey("owner1");

        vaultImplementation = new StrategyVault();

        factory = new StrategyVaultFactory(feeController, feeHandler, actionRegistry, address(vaultImplementation));

        vm.prank(owner1);
        vault1 = StrategyVault(payable(factory.deployVault()));

        deal(address(owner1), 100 ether);
    }

    ////////////////////////////////
    ////// createStrategy //////////
    ////////////////////////////////

    function test_createStrategy_Success(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        uint32 strategyID = 222;
        vm.prank(owner1);
        vault1.createStrategy(strategyID, creator, steps);

        //Assert
        IStrategyVault.Strategy memory strategy = vault1.strategy(strategyID);

        assertEq(strategy.creator, creator);
        assertEq(strategy.steps.length, numSteps);
    }

    function test_createStrategy_Revert_AlreadyExists(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;
        vm.prank(owner1);
        vault1.createStrategy(strategyID, creator, steps);

        vm.expectRevert(IStrategyVault.StrategyAlreadyExist.selector);
        vm.prank(owner1);
        vault1.createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Success_StepsWithCondition(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategyStepsWithCondition(numSteps);

        uint32 strategyID = 222;
        vm.prank(owner1);
        vault1.createStrategy(strategyID, creator, steps);

        //Assert
        IStrategyVault.Strategy memory strategy = vault1.strategy(strategyID);

        assertEq(strategy.creator, creator);
        assertEq(strategy.steps.length, numSteps);

        assertTrue(mockCondition.strategies(address(vault1), uint32(1)).length > 0);
    }

    function test_createStrategy_Revert_InvalidNextStepId(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategyStepsWithCondition(numSteps);

        steps[steps.length - 1].condition.result1 = 100; // Invalid next step ID

        uint32 strategyID = 222;
        vm.prank(owner1);
        vm.expectRevert(IStrategyVault.InvalidNextStepIndex.selector);
        vault1.createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidAction_NoContract(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        address invalidAction = makeAddr("invalid-address");
        steps[0].actions[0].target = invalidAction;
        steps[0].actions[0].actionType = IStrategyVault.ActionType.INTERNAL_ACTION;

        vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(true));

        uint32 strategyID = 222;
        vm.prank(owner1);
        vm.expectRevert(IStrategyVault.InvalidActionTarget.selector);
        vault1.createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidAction_NoInterface(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        Token invalidActionContract = new Token("Test", "TST", 1 ether);
        address invalidAction = address(invalidActionContract);
        steps[0].actions[0].target = invalidAction;
        steps[0].actions[0].actionType = IStrategyVault.ActionType.INTERNAL_ACTION;

        vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(true));

        uint32 strategyID = 222;
        vm.prank(owner1);
        vm.expectRevert(IStrategyVault.InvalidActionTarget.selector);
        vault1.createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidAction_IncorrectInterface(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        WrongInterfaceContract invalidActionContract = new WrongInterfaceContract();
        address invalidAction = address(invalidActionContract);
        steps[0].actions[0].target = invalidAction;
        steps[0].actions[0].actionType = IStrategyVault.ActionType.INTERNAL_ACTION;

        vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(true));

        uint32 strategyID = 222;
        vm.prank(owner1);
        vm.expectRevert(IStrategyVault.InvalidActionTarget.selector);
        vault1.createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidAction_ZeroAddress(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        address invalidAction = address(0);
        steps[0].actions[0].target = invalidAction;
        steps[0].actions[0].actionType = IStrategyVault.ActionType.EXTERNAL;

        vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(true));

        uint32 strategyID = 222;
        vm.prank(owner1);
        vm.expectRevert(IStrategyVault.InvalidActionTarget.selector);
        vault1.createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidAction_NotRegistered(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        address invalidAction = makeAddr("not-regisstered");
        steps[0].actions[0].target = invalidAction;
        steps[0].actions[0].actionType = IStrategyVault.ActionType.INTERNAL_ACTION;

        vm.mockCall(actionRegistry, abi.encodeWithSelector(IActionRegistry.isAllowed.selector), abi.encode(false));

        uint32 strategyID = 222;
        vm.prank(owner1);
        vm.expectRevert(IStrategyVault.InvalidActionTarget.selector);
        vault1.createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidCondition_NoInterface(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        Token invalidConditionContract = new Token("test", "TST", 1 ether);
        steps[0].condition.conditionAddress = address(invalidConditionContract);

        uint32 strategyID = 222;
        vm.prank(owner1);
        vm.expectRevert(IStrategyVault.InvalidCondition.selector);
        vault1.createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidCondition_IncorrectInterface(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        WrongInterfaceContract invalidConditionContract = new WrongInterfaceContract();
        steps[0].condition.conditionAddress = address(invalidConditionContract);

        uint32 strategyID = 222;
        vm.prank(owner1);
        vm.expectRevert(IStrategyVault.InvalidCondition.selector);
        vault1.createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_Revert_InvalidCondition_NoContract(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        steps[0].condition.conditionAddress = makeAddr("no-contract-address");

        uint32 strategyID = 222;
        vm.prank(owner1);
        vm.expectRevert(IStrategyVault.InvalidConditionAddress.selector);
        vault1.createStrategy(strategyID, creator, steps);
        vm.stopPrank();
    }

    function test_createStrategy_Empty() external {
        uint256 numSteps;
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;
        vm.prank(owner1);
        vm.expectRevert(IStrategyVault.InvalidStepArrayLength.selector);

        vault1.createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_EmptyNonZeroLength() external {
        uint256 numSteps = 2;
        IStrategyVault.StrategyStep[] memory steps = new IStrategyVault.StrategyStep[](numSteps);

        uint32 strategyID = 222;
        vm.prank(owner1);
        vm.expectRevert(abi.encodeWithSelector(IStrategyVault.NoConditionOrActions.selector, 0));
        vault1.createStrategy(strategyID, creator, steps);
    }

    function test_createStrategy_NotOwner() external {
        uint256 numSteps = 2;
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);

        uint32 strategyID = 222;
        vm.prank(makeAddr("bad-actor"));
        vm.expectRevert("OwnableUnauthorizedAccount(0x9B9e8cE40132FEc8159359e6c0a918b34B511214)");
        vault1.createStrategy(strategyID, creator, steps);
    }

    // //     /////////////////////////////////
    // //     ////// deleteStrategy ///////////
    // //     /////////////////////////////////

    function test_deleteStrategy_Success(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;
        vm.prank(owner1);
        vault1.createStrategy(strategyID, creator, steps);

        //Act
        vm.startPrank(owner1);
        vault1.deleteStrategy(strategyID);
        vm.stopPrank();

        //Assert
        assertTrue(vault1.strategy(strategyID).creator == address(0));
        assertTrue(vault1.strategy(strategyID).steps.length == 0);
    }

    function test_deleteStrategy_Success_StrategyWithConditions(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategyStepsWithCondition(numSteps);
        uint32 strategyID = 222;
        vm.prank(owner1);
        vault1.createStrategy(strategyID, creator, steps);
        //Act
        vm.startPrank(owner1);
        vault1.deleteStrategy(strategyID);
        vm.stopPrank();
        //Assert
        assertTrue(vault1.strategy(strategyID).creator == address(0));
        assertTrue(vault1.strategy(strategyID).steps.length == 0);
    }

    function test_deleteStrategy_Revert_StrategyInUse(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;
        vm.prank(owner1);
        vault1.createStrategy(strategyID, creator, steps);

        //Mock FeeController and FeeHandler
        vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(true));
        vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(true));

        vm.startPrank(owner1);
        uint32 conditionId = 2222;
        bytes memory addConditionData = abi.encodeCall(
            MockCondition.addCondition,
            (conditionId, MockCondition.Condition({result: true, active: true, updateable: true}))
        );
        // mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
        vault1.execute(address(mockCondition), 0, addConditionData);
        IStrategyVault.Condition memory condition =
            IStrategyVault.Condition({conditionAddress: address(mockCondition), id: 2222, result0: 0, result1: 0});
        vault1.createAutomation(1, strategyID, address(0), type(uint256).max, condition);
        vm.stopPrank();

        //Act

        vm.expectRevert(IStrategyVault.StrategyIsInUse.selector);
        vm.prank(owner1);
        vault1.deleteStrategy(strategyID);
    }

    function test_deleteStrategy_Revert_StrategyDoesNotExist(uint32 strategyId) external {
        vm.expectRevert(IStrategyVault.StrategyDoesNotExist.selector);
        vm.prank(owner1);
        vault1.deleteStrategy(strategyId); // Strategy ID doesn't exist
    }

    // /////////////////////////////////
    // ////// executeStrategy //////////
    // /////////////////////////////////

    function test_executeStrategy_Success(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;

        deal(address(vault1), 100 ether);

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
        vm.startPrank(owner1);
        vault1.createStrategy(strategyID, creator, steps);

        vault1.executeStrategy(strategyID);
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
        vm.prank(owner1);
        Token token = new Token("TestToken", "TT", 100 ether);

        vm.prank(owner1);
        token.transfer(address(vault1), 100 ether);

        IStrategyVault.StrategyStep[] memory steps =
            _createStrategyStepWithMultiExecutionAction(1, receivers, value, address(token));
        uint32 strategyID = 222;

        deal(address(vault1), 100 ether);

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
        vm.startPrank(owner1);
        vault1.createStrategy(strategyID, creator, steps);

        vault1.executeStrategy(strategyID);
        vm.stopPrank();

        //Assert
        assertTrue(token.balanceOf(receiver1) == 2 * value);
        assertTrue(token.balanceOf(receiver2) == 2 * value);
    }

    function test_executeStrategy_OOB_RevertWithValidiationError() external {
        uint256 numSteps = 2;
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        steps[0].condition.result0 = 2;
        steps[0].condition.result1 = 2;
        uint32 strategyID = 222;
        deal(address(vault1), 100 ether);
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
        vm.startPrank(owner1);
        vm.expectRevert(IStrategyVault.InvalidNextStepIndex.selector);

        vault1.createStrategy(strategyID, creator, steps);

        vm.stopPrank();
    }

    // /////////////////////////////////
    // ////// createAutomation /////////
    // /////////////////////////////////

    function test_createAutomation_Success(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;
        vm.prank(owner1);
        vault1.createStrategy(strategyID, creator, steps);

        //Mock FeeController and FeeHandler
        vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(true));
        vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(true));

        vm.startPrank(owner1);
        uint32 conditionId = 2222;
        // mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));

        bytes memory addConditionData = abi.encodeCall(
            MockCondition.addCondition,
            (conditionId, MockCondition.Condition({result: true, active: true, updateable: true}))
        );
        // mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
        vault1.execute(address(mockCondition), 0, addConditionData);

        IStrategyVault.Condition memory condition =
            IStrategyVault.Condition({conditionAddress: address(mockCondition), id: 2222, result0: 0, result1: 0});
        vault1.createAutomation(1, strategyID, address(0), type(uint256).max, condition);
        vm.stopPrank();

        //assert

        IStrategyVault.Automation memory automation = vault1.automation(1);
        assertEq(automation.strategyId, strategyID);
        assertEq(automation.condition.conditionAddress, address(mockCondition));
        assertEq(automation.condition.id, conditionId);
    }

    function test_createAutomation_Revert_InvalidPaymentToken_NotAllowed(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;
        vm.prank(owner1);
        vault1.createStrategy(strategyID, creator, steps);

        //Mock FeeController and FeeHandler
        vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(true));
        vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(false));

        address paymentToken = makeAddr("invalid-token");

        vm.startPrank(owner1);
        uint32 conditionId = 2222;
        // mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));

        bytes memory addConditionData = abi.encodeCall(
            MockCondition.addCondition,
            (conditionId, MockCondition.Condition({result: true, active: true, updateable: true}))
        );
        // mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
        vault1.execute(address(mockCondition), 0, addConditionData);

        IStrategyVault.Condition memory condition =
            IStrategyVault.Condition({conditionAddress: address(mockCondition), id: 2222, result0: 0, result1: 0});
        vm.expectRevert(IStrategyVault.PaymentTokenNotAllowed.selector);
        vault1.createAutomation(1, strategyID, paymentToken, type(uint256).max, condition);
        vm.stopPrank();
    }

    function test_createAutomation_Revert_InvalidPaymentToken_NotOracle(uint8 _numSteps) external {
        uint256 numSteps = bound(_numSteps, 1, 10);
        IStrategyVault.StrategyStep[] memory steps = _createStrategySteps(numSteps);
        uint32 strategyID = 222;
        vm.prank(owner1);
        vault1.createStrategy(strategyID, creator, steps);

        //Mock FeeController and FeeHandler
        vm.mockCall(feeController, abi.encodeWithSelector(IFeeController.hasOracle.selector), abi.encode(false));
        vm.mockCall(feeHandler, abi.encodeWithSelector(IFeeHandler.tokenAllowed.selector), abi.encode(true));

        address paymentToken = makeAddr("invalid-token");

        vm.startPrank(owner1);
        uint32 conditionId = 2222;
        bytes memory addConditionData = abi.encodeCall(
            MockCondition.addCondition,
            (conditionId, MockCondition.Condition({result: true, active: true, updateable: true}))
        );
        // mockCondition.addCondition(conditionId, MockCondition.Condition({result: true, active: true, updateable: true}));
        vault1.execute(address(mockCondition), 0, addConditionData);

        IStrategyVault.Condition memory condition =
            IStrategyVault.Condition({conditionAddress: address(mockCondition), id: 2222, result0: 0, result1: 0});
        vm.expectRevert(IStrategyVault.PaymentTokenNotAllowed.selector);
        vault1.createAutomation(1, strategyID, paymentToken, type(uint256).max, condition);
        vm.stopPrank();
    }

    function _createStrategySteps(uint256 numSteps) internal view returns (IStrategyVault.StrategyStep[] memory) {
        IStrategyVault.StrategyStep[] memory steps = new IStrategyVault.StrategyStep[](numSteps);

        for (uint256 i = 0; i < numSteps; i++) {
            IStrategyVault.Condition memory condition = IStrategyVault.Condition({
                conditionAddress: address(0),
                id: 0,
                result0: i == numSteps - 1 ? 0 : uint8(i),
                result1: i == numSteps - 1 ? 0 : uint8(i + 1)
            });

            IStrategyVault.Action[] memory actions = new IStrategyVault.Action[](2);

            actions[0] = IStrategyVault.Action({
                target: tokenReceiver,
                parameter: "",
                value: TOKEN_SEND_AMOUNT,
                selector: bytes4(0),
                actionType: IStrategyVault.ActionType.EXTERNAL,
                inputs: new IStrategyVault.ContextKey[](0), // Empty array
                output: IStrategyVault.ContextKey({ // Empty struct
                    key: "",
                    parameterReplacement: IStrategyVault.Parameter({
                        offset: 0,
                        length: 0,
                        paramType: IStrategyVault.ParamType.UINT256
                    })
                }),
                result: 0
            });

            actions[1] = IStrategyVault.Action({
                target: tokenReceiver,
                parameter: "",
                value: TOKEN_SEND_AMOUNT,
                selector: bytes4(0),
                actionType: IStrategyVault.ActionType.EXTERNAL,
                inputs: new IStrategyVault.ContextKey[](0), // Empty array
                output: IStrategyVault.ContextKey({ // Empty struct
                    key: "",
                    parameterReplacement: IStrategyVault.Parameter({
                        offset: 0,
                        length: 0,
                        paramType: IStrategyVault.ParamType.UINT256
                    })
                }),
                result: 0
            });

            steps[i] = IStrategyVault.StrategyStep({condition: condition, actions: actions});
        }

        return steps;
    }

    function _createStrategyStepsWithCondition(uint256 numSteps)
        internal
        returns (IStrategyVault.StrategyStep[] memory)
    {
        IStrategyVault.StrategyStep[] memory steps = new IStrategyVault.StrategyStep[](numSteps);
        for (uint256 i = 0; i < numSteps; i++) {
            IStrategyVault.Condition memory condition = IStrategyVault.Condition({
                conditionAddress: address(mockCondition),
                id: uint32(i + 1),
                result0: 0,
                result1: i == numSteps - 1 ? 0 : uint8(i + 1)
            });

            vm.prank(address(vault1));
            MockCondition.Condition memory _mockCondition =
                MockCondition.Condition({result: true, active: true, updateable: true});
            mockCondition.addCondition(uint32(i + 1), _mockCondition);

            IStrategyVault.Action[] memory actions = new IStrategyVault.Action[](2);

            actions[0] = IStrategyVault.Action({
                target: tokenReceiver,
                parameter: "",
                value: TOKEN_SEND_AMOUNT,
                selector: bytes4(0),
                actionType: IStrategyVault.ActionType.EXTERNAL,
                inputs: new IStrategyVault.ContextKey[](0), // Empty array
                output: IStrategyVault.ContextKey({ // Empty struct
                    key: "",
                    parameterReplacement: IStrategyVault.Parameter({
                        offset: 0,
                        length: 0,
                        paramType: IStrategyVault.ParamType.UINT256
                    })
                }),
                result: 0
            });

            actions[1] = IStrategyVault.Action({
                target: tokenReceiver,
                parameter: "",
                value: TOKEN_SEND_AMOUNT,
                selector: bytes4(0),
                actionType: IStrategyVault.ActionType.EXTERNAL,
                inputs: new IStrategyVault.ContextKey[](0), // Empty array
                output: IStrategyVault.ContextKey({ // Empty struct
                    key: "",
                    parameterReplacement: IStrategyVault.Parameter({
                        offset: 0,
                        length: 0,
                        paramType: IStrategyVault.ParamType.UINT256
                    })
                }),
                result: 0
            });

            steps[i] = IStrategyVault.StrategyStep({condition: condition, actions: actions});
        }

        return steps;
    }

    function _createStrategyStepWithMultiExecutionAction(
        uint32 conditionId,
        address[] memory receivers,
        uint256 value,
        address token
    ) internal returns (IStrategyVault.StrategyStep[] memory) {
        vm.prank(address(vault1));
        MockCondition.Condition memory _mockCondition =
            MockCondition.Condition({result: true, active: true, updateable: true});
        mockCondition.addCondition(conditionId, _mockCondition);

        IStrategyVault.StrategyStep[] memory steps = new IStrategyVault.StrategyStep[](1);

        IStrategyVault.Condition memory condition = IStrategyVault.Condition({
            conditionAddress: address(mockCondition),
            id: conditionId,
            result0: 0,
            result1: 0
        });

        IStrategyVault.Action[] memory actions = new IStrategyVault.Action[](2);

        MockAction actionContract = new MockAction();

        actions[0] = IStrategyVault.Action({
            target: address(actionContract),
            parameter: abi.encode(receivers, address(token), value),
            value: 0,
            selector: MockAction.execute.selector,
            actionType: IStrategyVault.ActionType.INTERNAL_ACTION,
            inputs: new IStrategyVault.ContextKey[](0), // Empty array
            output: IStrategyVault.ContextKey({ // Empty struct
                key: "REPLACEMENT_VALUE",
                parameterReplacement: IStrategyVault.Parameter({
                    offset: 0,
                    length: 32,
                    paramType: IStrategyVault.ParamType.UINT256
                })
            }),
            result: 0
        });

        IStrategyVault.ContextKey[] memory inputs = new IStrategyVault.ContextKey[](1);
        inputs[0] = IStrategyVault.ContextKey({
            key: "REPLACEMENT_VALUE",
            parameterReplacement: IStrategyVault.Parameter({
                offset: 64, // This is where 'value' is located
                length: 32, // uint256 is 32 bytes
                paramType: IStrategyVault.ParamType.UINT256
            })
        });
        actions[1] = IStrategyVault.Action({
            target: address(actionContract),
            parameter: abi.encode(receivers, address(token), uint256(0)),
            value: 0,
            selector: MockAction.execute.selector,
            actionType: IStrategyVault.ActionType.INTERNAL_ACTION,
            inputs: inputs,
            output: IStrategyVault.ContextKey({ // Empty struct
                key: "",
                parameterReplacement: IStrategyVault.Parameter({
                    offset: 0,
                    length: 0,
                    paramType: IStrategyVault.ParamType.UINT256
                })
            }),
            result: 0
        });

        steps[0] = IStrategyVault.StrategyStep({condition: condition, actions: actions});

        return steps;
    }
}
