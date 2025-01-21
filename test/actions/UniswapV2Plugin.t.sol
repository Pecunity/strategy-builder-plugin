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

import {UniswapV2Plugin} from "../../src/actions/uniswap-v2/UniswapV2Plugin.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapV2PluginTest is Test {
    using ECDSA for bytes32;

    IEntryPoint entryPoint;
    UpgradeableModularAccount account1;
    UniswapV2Plugin uniswapV2Plugin;

    address owner1;
    uint256 owner1Key;
    address payable beneficiary;

    uint256 constant CALL_GAS_LIMIT = 800_000;
    uint256 constant VERIFICATION_GAS_LIMIT = 1000000;

    uint256 nonce = 0;

    address public constant ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; //Aerodrome Router
    address public constant USDC = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address public constant WETH = 0x4200000000000000000000000000000000000006;

    string BASE_MAINNET_FORK = vm.envString("BASE_MAINNET_FORK");
    uint256 baseFork;

    function setUp() external {
        //Fork the base chain
        baseFork = vm.createFork(BASE_MAINNET_FORK);
        vm.selectFork(baseFork);

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

        uniswapV2Plugin = new UniswapV2Plugin(ROUTER);
        bytes32 manifestHash = keccak256(abi.encode(uniswapV2Plugin.pluginManifest()));

        FunctionReference[] memory dependencies = new FunctionReference[](1);
        dependencies[0] = FunctionReferenceLib.pack(
            address(singleOwnerPlugin), uint8(ISingleOwnerPlugin.FunctionId.USER_OP_VALIDATION_OWNER)
        );

        // install this plugin on the account as the owner
        vm.prank(owner1);
        account1.installPlugin({
            plugin: address(uniswapV2Plugin),
            manifestHash: manifestHash,
            pluginInstallData: "0x",
            dependencies: dependencies
        });
    }

    //////////////////////////////////////////
    ////// swapExactTokensForTokens //////////
    //////////////////////////////////////////

    function test_swapExactTokensForTokens_Success(uint256 amountIn) external {
        uint256 amountIn = bound(amountIn, 1000, 1 * 10 ** 18);
        deal(WETH, address(account1), amountIn);

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        uint256 amountsOut = IUniswapV2Router01(ROUTER).getAmountsOut(amountIn, path)[path.length - 1];

        uint256 amountsOutMin = amountsOut * 80 / 100;

        // create a user operation which has the calldata to specify we'd like to increment
        UserOperation memory userOp = UserOperation({
            sender: address(account1),
            nonce: nonce,
            initCode: "",
            callData: abi.encodeCall(uniswapV2Plugin.swapExactTokensForTokens, (amountIn, amountsOutMin, path)),
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

        assertGt(IERC20(USDC).balanceOf(address(account1)), amountsOutMin);
    }

    //////////////////////////////////////////
    ////// swapTokensForExactTokens //////////
    //////////////////////////////////////////

    function test_swapTokensForExactTokens_Success(uint256 amountOut) external {
        uint256 amountOut = bound(amountOut, 1000, 1 * 10 ** 18);

        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = WETH;

        uint256 amountIn = IUniswapV2Router01(ROUTER).getAmountsIn(amountOut, path)[0];

        uint256 amountInMax = amountIn * 110 / 100;

        deal(USDC, address(account1), amountInMax);

        // create a user operation which has the calldata to specify we'd like to increment
        UserOperation memory userOp = UserOperation({
            sender: address(account1),
            nonce: nonce,
            initCode: "",
            callData: abi.encodeCall(uniswapV2Plugin.swapTokensForExactTokens, (amountOut, amountInMax, path)),
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

        assertEq(IERC20(WETH).balanceOf(address(account1)), amountOut);
    }

    function test_swapTokensForExactTokens_ExactAmountOutMax(uint256 amountOut) external {
        uint256 amountOut = bound(amountOut, 1000, 1 * 10 ** 18);

        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = WETH;

        uint256 amountIn = IUniswapV2Router01(ROUTER).getAmountsIn(amountOut, path)[0];

        uint256 amountInMax = amountIn;

        deal(USDC, address(account1), amountInMax);

        // create a user operation which has the calldata to specify we'd like to increment
        UserOperation memory userOp = UserOperation({
            sender: address(account1),
            nonce: nonce,
            initCode: "",
            callData: abi.encodeCall(uniswapV2Plugin.swapTokensForExactTokens, (amountOut, amountInMax, path)),
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

        assertEq(IERC20(WETH).balanceOf(address(account1)), amountOut);
    }
}
