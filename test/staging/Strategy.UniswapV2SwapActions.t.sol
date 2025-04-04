// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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

import {PriceOracle} from "../../src/PriceOracle.sol";
import {FeeController} from "../../src/FeeController.sol";
import {FeeHandler} from "../../src/FeeHandler.sol";

import {IFeeController} from "../../src/interfaces/IFeeController.sol";

import {StrategyBuilderPlugin} from "../../src/StrategyBuilderPlugin.sol";
import {IStrategyBuilderPlugin} from "../../src/interfaces/IStrategyBuilderPlugin.sol";

import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

import {UniswapV2SwapActions} from "../../src/actions/uniswap-v2/UniswapV2SwapActions.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {Token} from "../../src/test/mocks/MockToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StrategyUniswapV2SwapActionTest is Test {
    using ECDSA for bytes32;

    IEntryPoint entryPoint;
    UpgradeableModularAccount account1;

    address owner1;
    uint256 owner1Key;
    address payable beneficiary;

    uint256 constant CALL_GAS_LIMIT = 1_000_000;
    uint256 constant VERIFICATION_GAS_LIMIT = 1000000;

    uint256 nonce = 0;

    PriceOracle oracle;
    FeeController feeController;
    FeeHandler feeHandler;
    StrategyBuilderPlugin strategyBuilderPlugin;

    address public OWNER = makeAddr("owner");
    address public VAULT = makeAddr("vault");

    address public pythOracle = 0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a;

    uint256 public constant BENEFICARY_PERCENTAGE = 2000;
    uint256 public constant CREATOR_PERCENTAGE = 500;
    uint256 public constant VAULT_PERCENTAGE = 7500;

    uint256[] public maxFeeLimits = [500, 1000, 200];
    uint256[] public minFeesInUSD = [1e18, 2e18, 0.5e18];

    bytes32 public oracleIDETH = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
    bytes32 public oracleIDStable = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
    bytes32 public oracleIDArb = 0x3fa4252848f9f0a1480be62745a4629d9eb1322aebab8a791e344b3b9c1adcf5;

    // Uniswap V2 State Variables + SetUp
    UniswapV2SwapActions swapActions;

    address public constant ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; //Aerodrome Router
    // address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    // address public constant TOKEN_1 = 0x8e306E02ec1EFFC4fDAd3f952fbEEebf3730ae19;

    Token token1;
    Token token2;

    address public TOKEN_HOLDER = makeAddr("token-holder");
    address public CREATOR = makeAddr("creator");

    uint256 public constant MAX_TOKEN_SUPPLY = 1_000_000 * 1e18;
    uint256 public constant MAX_ETH = 100 ether;

    string BASE_MAINNET_FORK = vm.envString("BASE_MAINNET_FORK");
    uint256 baseFork;

    function setUp() public {
        //Fork the base chain
        baseFork = vm.createFork(BASE_MAINNET_FORK);
        vm.selectFork(baseFork);

        swapActions = new UniswapV2SwapActions(ROUTER);

        deal(TOKEN_HOLDER, MAX_ETH);
        vm.startPrank(TOKEN_HOLDER);
        token1 = new Token("Token 1", "T1", MAX_TOKEN_SUPPLY);
        token2 = new Token("Token 2", "T2", MAX_TOKEN_SUPPLY);

        token1.approve(ROUTER, MAX_TOKEN_SUPPLY);
        token2.approve(ROUTER, MAX_TOKEN_SUPPLY / 2);

        IUniswapV2Router01(ROUTER).addLiquidity(
            address(token1),
            address(token2),
            MAX_TOKEN_SUPPLY / 2,
            MAX_TOKEN_SUPPLY / 2,
            0,
            0,
            TOKEN_HOLDER,
            block.timestamp + 10
        );

        IUniswapV2Router01(ROUTER).addLiquidityETH{value: MAX_ETH}(
            address(token1), MAX_TOKEN_SUPPLY / 2, 0, 0, TOKEN_HOLDER, block.timestamp + 10
        );

        vm.stopPrank();

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

        //Deploy all necessary contracts for the strategy builder plugin
        vm.startPrank(OWNER);
        oracle = new PriceOracle(pythOracle, OWNER);
        feeController = new FeeController(address(oracle), maxFeeLimits, minFeesInUSD, OWNER);
        feeHandler = new FeeHandler(VAULT, BENEFICARY_PERCENTAGE, CREATOR_PERCENTAGE, VAULT_PERCENTAGE, OWNER);
        strategyBuilderPlugin = new StrategyBuilderPlugin(address(feeController), address(feeHandler));
        vm.stopPrank();

        vm.startPrank(OWNER);

        feeController.setTokenGetter(
            UniswapV2SwapActions.swapExactTokensForTokens.selector, address(swapActions), address(swapActions)
        );
        feeController.setFunctionFeeConfig(
            UniswapV2SwapActions.swapExactTokensForTokens.selector, IFeeController.FeeType.Deposit, 200
        );

        feeHandler.updateTokenAllowance(address(0), true);

        oracle.setOracleID(address(0), oracleIDETH);
        oracle.setOracleID(address(token1), oracleIDStable);
        oracle.setOracleID(address(token2), oracleIDArb);

        // PythStructs.Price memory price = PythStructs.Price({price: 2})
        // vm.mockCall(PYTH_ORACLE, abi.encodeCall(IPyth.getPriceUnsafe.selector), );

        vm.stopPrank();

        //adding strategy builder plugin to the account
        bytes32 manifestHash = keccak256(abi.encode(strategyBuilderPlugin.pluginManifest()));
        console.logBytes32(manifestHash);

        // we will have a single function dependency for our counter contract: the single owner user op validation
        // we'll use this to ensure that only an owner can sign a user operation that can successfully increment
        FunctionReference[] memory dependencies = new FunctionReference[](1);
        dependencies[0] = FunctionReferenceLib.pack(
            address(singleOwnerPlugin), uint8(ISingleOwnerPlugin.FunctionId.USER_OP_VALIDATION_OWNER)
        );

        bytes21 _output = bytes21(FunctionReference.unwrap(dependencies[0]));

        console.logBytes21(_output);
        console.logAddress(address(singleOwnerPlugin));

        // install this plugin on the account as the owner
        vm.prank(owner1);
        account1.installPlugin({
            plugin: address(strategyBuilderPlugin),
            manifestHash: manifestHash,
            pluginInstallData: "0x",
            dependencies: dependencies
        });
    }

    function test_executeStrategy_Strategy_1() external {
        //Creating the strategy

        uint256 token2SwapAmount = 200 ether;
        deal(address(token2), address(account1), token2SwapAmount);
        address[] memory firstSwapPath = new address[](2);
        firstSwapPath[0] = address(token2);
        firstSwapPath[1] = address(token1);

        IStrategyBuilderPlugin.StrategyStep[] memory steps = new IStrategyBuilderPlugin.StrategyStep[](1);

        IStrategyBuilderPlugin.Condition memory emptyCondition;

        IStrategyBuilderPlugin.Action[] memory actions = new IStrategyBuilderPlugin.Action[](1);
        actions[0] = IStrategyBuilderPlugin.Action({
            selector: UniswapV2SwapActions.swapExactTokensForTokens.selector,
            parameter: abi.encode(token2SwapAmount, 0, firstSwapPath, address(account1)),
            actionType: IStrategyBuilderPlugin.ActionType.INTERNAL_ACTION,
            target: address(swapActions),
            value: 0
        });

        IStrategyBuilderPlugin.StrategyStep memory step =
            IStrategyBuilderPlugin.StrategyStep({condition: emptyCondition, actions: actions});

        steps[0] = step;

        uint16 id = 16;

        sendUserOperation(abi.encodeCall(StrategyBuilderPlugin.createStrategy, (id, CREATOR, steps)));

        sendUserOperation(abi.encodeCall(StrategyBuilderPlugin.executeStrategy, (id)));

        assert(IERC20(address(token1)).balanceOf(address(account1)) > 0);
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

    function getRandomBytes32() public view returns (bytes32) {
        return keccak256(abi.encodePacked(block.timestamp, msg.sender, block.prevrandao));
    }
}

// contract Strategy1Test is Test {
//     using ECDSA for bytes32;

//     IEntryPoint entryPoint;
//     UpgradeableModularAccount account1;
//     StrategyBuilderPlugin strategyBuilderPlugin;
//     UniswapV2SwapActions uniswapV2Actions;
//     address owner1;
//     uint256 owner1Key;
//     address payable beneficiary;

//     uint256 constant CALL_GAS_LIMIT = 800_000;
//     uint256 constant VERIFICATION_GAS_LIMIT = 1000000;

//     uint256 nonce = 0;

//     FeeManagerMock feeManager;

//     address public constant ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
//     address public constant USDC = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
//     address public constant WETH = 0x4200000000000000000000000000000000000006;

//     //Fork Informations
//     string BASE_MAINNET_FORK = vm.envString("BASE_MAINNET_FORK");
//     uint256 baseFork;

//     /**
//      * Strategy 1 Staging Test:
//      *  1. Fork the Base Chain
//      *  2. Add Strategy Builder Plugin
//      *  3. Add UniswapV2 Plugin
//      *  4. Deploy the TimeCondition Contract
//      *  5. Add Strategy
//      *     5.1 StrategyStep without condition => Swap token x
//      *  6. Execute Strategy
//      *  7. Check if tokens were swapped
//      */

//     function setUp() public {
//         //Fork the base chain
//         baseFork = vm.createFork(BASE_MAINNET_FORK);
//         vm.selectFork(baseFork);

//         // we'll be using the entry point so we can send a user operation through
//         // in this case our plugin only accepts calls to increment via user operations so this is essential
//         entryPoint = IEntryPoint(address(new EntryPoint()));

//         // our modular smart contract account will be installed with the single owner plugin
//         // so we have a way to determine who is authorized to do things on this account
//         // we'll use this plugin's validation for our increment function
//         SingleOwnerPlugin singleOwnerPlugin = new SingleOwnerPlugin();
//         MSCAFactoryFixture factory = new MSCAFactoryFixture(entryPoint, singleOwnerPlugin);

//         // the beneficiary of the fees at the entry point
//         beneficiary = payable(makeAddr("beneficiary"));

//         // create a single owner for this account and provide the address to our modular account
//         // we'll also add ether to our account to pay for gas fees
//         (owner1, owner1Key) = makeAddrAndKey("owner1");
//         account1 = UpgradeableModularAccount(payable(factory.createAccount(owner1, 0)));
//         vm.deal(address(account1), 100 ether);

//         // we will have a single function dependency for our counter contract: the single owner user op validation
//         // we'll use this to ensure that only an owner can sign a user operation that can successfully increment
//         FunctionReference[] memory dependencies = new FunctionReference[](1);
//         dependencies[0] = FunctionReferenceLib.pack(
//             address(singleOwnerPlugin), uint8(ISingleOwnerPlugin.FunctionId.USER_OP_VALIDATION_OWNER)
//         );

//         //Deploy a mock feeManager
//         feeManager = new FeeManagerMock();

//         strategyBuilderPlugin = new StrategyBuilderPlugin(address(feeManager));
//         bytes32 manifestHash = keccak256(abi.encode(strategyBuilderPlugin.pluginManifest()));

//         // install this plugin on the account as the owner
//         vm.prank(owner1);
//         account1.installPlugin({
//             plugin: address(strategyBuilderPlugin),
//             manifestHash: manifestHash,
//             pluginInstallData: "0x",
//             dependencies: dependencies
//         });

//         // deploy the uniswap action contract
//         uniswapV2Actions = new UniswapV2SwapActions(ROUTER);
//     }

//     function test_executeStrategy_Success(uint256 _amountIn) external {
//         // swap exact tokens for tokens after a special time
//         uint256 amountIn = bound(_amountIn, 1000, 1 * 10 ** 18);
//         deal(WETH, address(account1), amountIn);

//         address[] memory path = new address[](2);
//         path[0] = WETH;
//         path[1] = USDC;

//         IStrategyBuilderPlugin.StrategyStep[] memory steps = new IStrategyBuilderPlugin.StrategyStep[](1);

//         IStrategyBuilderPlugin.Condition memory emptyCondition;

//         IStrategyBuilderPlugin.Action[] memory actions = new IStrategyBuilderPlugin.Action[](1);
//         actions[0] = IStrategyBuilderPlugin.Action({
//             selector: UniswapV2SwapActions.swapExactTokensForTokens.selector,
//             parameter: abi.encode(amountIn, 0, path, address(account1)),
//             actionType: IStrategyBuilderPlugin.ActionType.INTERNAL_ACTION,
//             target: address(uniswapV2Actions),
//             value: 0
//         });

//         IStrategyBuilderPlugin.StrategyStep memory step =
//             IStrategyBuilderPlugin.StrategyStep({condition: emptyCondition, actions: actions});

//         steps[0] = step;

//         (, bytes memory result) = address(uniswapV2Actions).call(
//             abi.encodeCall(UniswapV2SwapActions.swapExactTokensForTokens, (amountIn, 0, path, address(account1)))
//         );

//         address _creator = makeAddr("creator");
//         uint16 _id = 16;

//         sendUserOperation(abi.encodeCall(StrategyBuilderPlugin.addStrategy, (_id, _creator, steps)));

//         //check strategy is created
//         IStrategyBuilderPlugin.Strategy memory strategy = strategyBuilderPlugin.strategy(address(account1), _id);

//         assertGt(strategy.steps.length, 0);

//         //execute strategy

//         sendUserOperation(abi.encodeCall(StrategyBuilderPlugin.executeStrategy, (_id)));

//         assertGt(IERC20(USDC).balanceOf(address(account1)), 0);
//     }

//     /* ====== HELPER FUNCTIONS ====== */

//     function sendUserOperation(bytes memory callData) internal {
//         // create a user operation which has the calldata to specify we'd like to increment
//         UserOperation memory userOp = UserOperation({
//             sender: address(account1),
//             nonce: nonce,
//             initCode: "",
//             callData: callData,
//             callGasLimit: CALL_GAS_LIMIT,
//             verificationGasLimit: VERIFICATION_GAS_LIMIT,
//             preVerificationGas: 0,
//             maxFeePerGas: 2,
//             maxPriorityFeePerGas: 1,
//             paymasterAndData: "",
//             signature: ""
//         });

//         // sign this user operation with the owner, otherwise it will revert due to the singleowner validation
//         bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());
//         userOp.signature = abi.encodePacked(r, s, v);

//         // send our single user operation to increment our count
//         UserOperation[] memory userOps = new UserOperation[](1);
//         userOps[0] = userOp;
//         entryPoint.handleOps(userOps, beneficiary);

//         nonce++;
//     }
// }
