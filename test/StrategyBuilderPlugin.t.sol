// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {UpgradeableModularAccount} from "erc6900/reference-implementation/src/account/UpgradeableModularAccount.sol";
import {FunctionReference} from "erc6900/reference-implementation/src/interfaces/IPluginManager.sol";
import {FunctionReferenceLib} from "erc6900/reference-implementation/src/helpers/FunctionReferenceLib.sol";
import {SingleOwnerPlugin} from "erc6900/reference-implementation/src/plugins/owner/SingleOwnerPlugin.sol";
import {ISingleOwnerPlugin} from "erc6900/reference-implementation/src/plugins/owner/ISingleOwnerPlugin.sol";
import {MSCAFactoryFixture} from "erc6900/reference-implementation/test/mocks/MSCAFactoryFixture.sol";

import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";
import {EntryPoint} from "@eth-infinitism/account-abstraction/core/EntryPoint.sol";
import {UserOperation} from "@eth-infinitism/account-abstraction/interfaces/UserOperation.sol";

import {StrategyBuilderPlugin, StrategyBuilderPlugin__AutomationNotExecutable} from "../src/StrategyBuilderPlugin.sol";
import {IStrategyBuilderPlugin} from "../src/interfaces/IStrategyBuilderPlugin.sol";

import {Token} from "../src/test/mocks/MockToken.sol";
import {MockCondition} from "../src/test/mocks/MockCondition.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFeeManager} from "../src/interfaces/IFeeManager.sol";

contract StrategyBuilderTest is Test {
    using ECDSA for bytes32;

    IEntryPoint entryPoint;
    UpgradeableModularAccount account1;
    StrategyBuilderPlugin strategyBuilderPlugin;
    address owner1;
    uint256 owner1Key;
    address payable beneficiary;

    address feeManager = makeAddr("fee-manager");
    address receiver = makeAddr("receiver");
    address executor = makeAddr("executor");
    address octoInk = makeAddr("octo-ink");

    uint256 constant CALL_GAS_LIMIT = 800_000;
    uint256 constant VERIFICATION_GAS_LIMIT = 1000000;

    Token token;
    MockCondition condition;

    uint256 constant MAX_TOKEN_SUPPLY = 1_000_000 * 1e18;
    uint256 constant FIXED_FEE = 100;

    uint256 nonce = 0;

    function setUp() public {
        // we'll be using the entry point so we can send a user operation through
        // in this case our plugin only accepts calls to increment via user operations so this is essential
        entryPoint = IEntryPoint(address(new EntryPoint()));

        // our modular smart contract account will be installed with the single owner plugin
        // so we have a way to determine who is authorized to do things on this account
        // we'll use this plugin's validation for our increment function
        SingleOwnerPlugin singleOwnerPlugin = new SingleOwnerPlugin();
        MSCAFactoryFixture factory = new MSCAFactoryFixture(entryPoint, singleOwnerPlugin);

        // the beneficiary of the fees at the entry point
        beneficiary = payable(makeAddr("beneficiary"));

        // create a single owner for this account and provide the address to our modular account
        // we'll also add ether to our account to pay for gas fees
        (owner1, owner1Key) = makeAddrAndKey("owner1");
        account1 = UpgradeableModularAccount(payable(factory.createAccount(owner1, 0)));
        vm.deal(address(account1), 100 ether);

        strategyBuilderPlugin = new StrategyBuilderPlugin(feeManager);
        bytes32 manifestHash = keccak256(abi.encode(strategyBuilderPlugin.pluginManifest()));

        // we will have a single function dependency for our counter contract: the single owner user op validation
        // we'll use this to ensure that only an owner can sign a user operation that can successfully increment
        FunctionReference[] memory dependencies = new FunctionReference[](1);
        dependencies[0] = FunctionReferenceLib.pack(
            address(singleOwnerPlugin), uint8(ISingleOwnerPlugin.FunctionId.USER_OP_VALIDATION_OWNER)
        );

        // install this plugin on the account as the owner
        vm.prank(owner1);
        account1.installPlugin({
            plugin: address(strategyBuilderPlugin),
            manifestHash: manifestHash,
            pluginInstallData: "0x",
            dependencies: dependencies
        });

        vm.prank(owner1);
        token = new Token("Mock Token","MOCK",MAX_TOKEN_SUPPLY);

        vm.prank(owner1);
        token.transfer(address(account1), MAX_TOKEN_SUPPLY);

        condition = new MockCondition();
        MockCondition.Condition memory _condition = MockCondition.Condition({result: true, active: true});
        vm.prank(address(account1));
        condition.addCondition(0, _condition);
    }

    /////////////////////////////
    ////// addStrategy //////////
    /////////////////////////////

    function test_addStrategy_Success() public {
        IStrategyBuilderPlugin.StrategyStep[] memory steps = new IStrategyBuilderPlugin.StrategyStep[](1);

        IStrategyBuilderPlugin.Condition memory emptyCondition;

        IStrategyBuilderPlugin.Action[] memory actions = new IStrategyBuilderPlugin.Action[](2);
        actions[0] = IStrategyBuilderPlugin.Action({
            selector: UpgradeableModularAccount.execute.selector,
            parameter: abi.encode(1, 1, 1),
            actionType: IStrategyBuilderPlugin.ActionType.EXTERNAL,
            target: receiver,
            value: 1
        });

        IStrategyBuilderPlugin.StrategyStep memory step =
            IStrategyBuilderPlugin.StrategyStep({condition: emptyCondition, actions: actions});

        steps[0] = step;

        address _creator = makeAddr("creator");
        uint16 _id = 16;

        sendUserOperation(abi.encodeCall(StrategyBuilderPlugin.addStrategy, (_id, _creator, steps)));

        IStrategyBuilderPlugin.Strategy memory strategy = strategyBuilderPlugin.strategy(address(account1), _id);
        assertEq(strategy.creator, _creator);

        assertEq(strategy.steps[0].actions.length, 2);
    }

    /////////////////////////////////
    ////// executeStrategy //////////
    /////////////////////////////////

    function test_executeStrategy_Success(uint256 amount) external {
        amount = bound(amount, 1, MAX_TOKEN_SUPPLY - 1);

        strategyWithConditionAdded(amount);

        //Mock Fee Manager calls
        vm.mockCall(
            feeManager,
            abi.encodeWithSelector(IFeeManager.getFeeType.selector),
            abi.encode(IFeeManager.FeeType.FixedFee)
        );

        vm.mockCall(feeManager, abi.encodeWithSelector(IFeeManager.getFixedFee.selector), abi.encode(FIXED_FEE));

        sendUserOperation(abi.encodeCall(StrategyBuilderPlugin.executeStrategy, (1)));

        assert(IERC20(token).balanceOf(receiver) > 0);
    }

    function test_executeStrategy_TwoSteps(uint256 amount) external {
        amount = bound(amount, 1, MAX_TOKEN_SUPPLY - 1);

        strategyWithTwoStepsAdd(amount);

        //Mock Fee Manager calls
        vm.mockCall(
            feeManager,
            abi.encodeWithSelector(IFeeManager.getFeeType.selector),
            abi.encode(IFeeManager.FeeType.FixedFee)
        );

        vm.mockCall(feeManager, abi.encodeWithSelector(IFeeManager.getFixedFee.selector), abi.encode(FIXED_FEE));

        // create a user operation which has the calldata to specify we'd like to increment
        sendUserOperation(abi.encodeCall(StrategyBuilderPlugin.executeStrategy, (1)));

        assert(IERC20(token).balanceOf(receiver) > 0);
    }

    /////////////////////////////////
    ////// deleteStrategy ///////////
    /////////////////////////////////

    function test_deleteStrategy_Success() external {
        uint16 _id = 1;
        uint256 transfer = 1 ether;
        strategyWithConditionAdded(transfer);

        sendUserOperation(abi.encodeCall(StrategyBuilderPlugin.deleteStrategy, (_id)));

        IStrategyBuilderPlugin.Strategy memory strategy = strategyBuilderPlugin.strategy(address(account1), _id);
        assertEq(strategy.creator, address(0));

        assertEq(strategy.steps.length, 0);
    }

    //////////////////////////////////
    ////// activateAutomation ////////
    //////////////////////////////////

    function test_addAutomation_Success() external {
        uint256 amount = 1 ether;

        strategyWithConditionAdded(amount);

        IStrategyBuilderPlugin.Condition memory _automationCondition =
            IStrategyBuilderPlugin.Condition({conditionAddress: address(condition), id: 1, result1: 0, result0: 0});

        sendUserOperation(
            abi.encodeCall(StrategyBuilderPlugin.activateAutomation, (1, 1, address(0), 1 ether, _automationCondition))
        );

        address conditionAddress = strategyBuilderPlugin.automation(address(account1), 1).condition.conditionAddress;

        assertEq(conditionAddress, address(condition));
    }

    //////////////////////////////////
    ////// executeAutomation /////////
    //////////////////////////////////

    function test_executeAutomation_Success() external {
        uint256 amount = 1 ether;

        strategyWithConditionAdded(amount);

        activateAutomation(0);

        mockFeeManager();

        address executor = makeAddr("executor");

        vm.prank(executor);
        strategyBuilderPlugin.executeAutomation(1, address(account1), executor);
    }

    function test_executeAutomation_ConditionIsFalse() external {
        uint256 amount = 1 ether;

        strategyWithConditionAdded(amount);

        MockCondition.Condition memory _condition = MockCondition.Condition({result: false, active: true});
        vm.prank(address(account1));
        condition.addCondition(1, _condition);
        activateAutomation(1);

        mockFeeManager();

        address executor = makeAddr("executor");

        vm.prank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(StrategyBuilderPlugin__AutomationNotExecutable.selector, address(condition), 1)
        );
        strategyBuilderPlugin.executeAutomation(1, address(account1), executor);
    }

    //////////////////////////////////
    ////// deleteAutomation /////////
    //////////////////////////////////

    function test_deleteAutomation_Success() external {
        uint256 amount = 1 ether;

        strategyWithConditionAdded(amount);

        activateAutomation(0);

        sendUserOperation(abi.encodeCall(StrategyBuilderPlugin.deleteAutomation, (1)));

        StrategyBuilderPlugin.Automation memory _automation = strategyBuilderPlugin.automation(address(account1), 1);

        assertEq(_automation.condition.conditionAddress, address(0));
    }

    //////////////////////
    ////// HELPER ////////
    //////////////////////

    function strategyWithConditionAdded(uint256 transferAmount) internal {
        IStrategyBuilderPlugin.StrategyStep[] memory steps = new IStrategyBuilderPlugin.StrategyStep[](1);

        IStrategyBuilderPlugin.Condition memory _condition;
        _condition.conditionAddress = address(condition);

        IStrategyBuilderPlugin.Action[] memory actions = new IStrategyBuilderPlugin.Action[](2);
        actions[0] = IStrategyBuilderPlugin.Action({
            selector: IERC20.transfer.selector,
            parameter: abi.encode(receiver, transferAmount),
            actionType: IStrategyBuilderPlugin.ActionType.EXTERNAL,
            target: address(token),
            value: 0
        });

        IStrategyBuilderPlugin.StrategyStep memory step =
            IStrategyBuilderPlugin.StrategyStep({condition: _condition, actions: actions});

        steps[0] = step;
        address _creator = makeAddr("creator");
        uint16 _id = 1;

        sendUserOperation(abi.encodeCall(StrategyBuilderPlugin.addStrategy, (_id, _creator, steps)));
    }

    function strategyWithTwoStepsAdd(uint256 transferAmount) internal {
        IStrategyBuilderPlugin.StrategyStep[] memory steps = new IStrategyBuilderPlugin.StrategyStep[](2);

        IStrategyBuilderPlugin.Condition memory _condition;
        _condition.conditionAddress = address(0);
        _condition.result1 = 1;

        IStrategyBuilderPlugin.Action[] memory actions = new IStrategyBuilderPlugin.Action[](1);
        actions[0] = IStrategyBuilderPlugin.Action({
            selector: IERC20.transfer.selector,
            parameter: abi.encode(receiver, transferAmount),
            actionType: IStrategyBuilderPlugin.ActionType.EXTERNAL,
            target: address(token),
            value: 0
        });

        IStrategyBuilderPlugin.StrategyStep memory step =
            IStrategyBuilderPlugin.StrategyStep({condition: _condition, actions: actions});

        steps[0] = step;

        MockCondition.Condition memory _falseCondition = MockCondition.Condition({result: false, active: true});
        vm.prank(address(account1));
        condition.addCondition(1, _falseCondition);

        IStrategyBuilderPlugin.Condition memory _conditionStepTwo;
        _conditionStepTwo.conditionAddress = address(condition);
        _conditionStepTwo.id = 1;

        steps[1] = IStrategyBuilderPlugin.StrategyStep({condition: _conditionStepTwo, actions: actions});

        address _creator = makeAddr("creator");
        uint16 _id = 1;

        // create a user operation which has the calldata to specify we'd like to increment
        sendUserOperation(abi.encodeCall(StrategyBuilderPlugin.addStrategy, (_id, _creator, steps)));
    }

    function activateAutomation(uint16 conditionId) internal {
        IStrategyBuilderPlugin.Condition memory _automationCondition = IStrategyBuilderPlugin.Condition({
            conditionAddress: address(condition),
            id: conditionId,
            result1: 0,
            result0: 0
        });

        sendUserOperation(
            abi.encodeCall(StrategyBuilderPlugin.activateAutomation, (1, 1, address(0), 1 ether, _automationCondition))
        );
    }

    function mockFeeManager() internal {
        vm.mockCall(
            feeManager,
            abi.encodeWithSelector(IFeeManager.getFeeType.selector),
            abi.encode(IFeeManager.FeeType.FixedFee)
        );

        vm.mockCall(feeManager, abi.encodeWithSelector(IFeeManager.getFixedFee.selector), abi.encode(FIXED_FEE));

        vm.mockCall(feeManager, abi.encodeWithSelector(IFeeManager.prepareForPayment.selector), abi.encode(FIXED_FEE));

        vm.mockCall(feeManager, abi.encodeWithSelector(IFeeManager.octoInk.selector), abi.encode(octoInk));

        vm.mockCall(octoInk, abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));

        vm.mockCall(feeManager, abi.encodeWithSelector(IFeeManager.handleFee.selector), abi.encode(true));
    }

    /* ====== HELPER FUNCTIONS ====== */

    function sendUserOperation(bytes memory callData) internal {
        // create a user operation which has the calldata to specify we'd like to increment
        UserOperation memory userOp = UserOperation({
            sender: address(account1),
            nonce: nonce,
            initCode: "",
            callData: callData,
            callGasLimit: CALL_GAS_LIMIT,
            verificationGasLimit: VERIFICATION_GAS_LIMIT,
            preVerificationGas: 0,
            maxFeePerGas: 2,
            maxPriorityFeePerGas: 1,
            paymasterAndData: "",
            signature: ""
        });

        // sign this user operation with the owner, otherwise it will revert due to the singleowner validation
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = abi.encodePacked(r, s, v);

        // send our single user operation to increment our count
        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;
        entryPoint.handleOps(userOps, beneficiary);

        nonce++;
    }
}
