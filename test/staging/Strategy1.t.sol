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

import {
    StrategyBuilderPlugin, StrategyBuilderPlugin__AutomationNotExecutable
} from "../../src/StrategyBuilderPlugin.sol";
import {IStrategyBuilderPlugin} from "../../src/interfaces/IStrategyBuilderPlugin.sol";
import {FeeManagerMock} from "../../src/test/mocks/FeeManagerMock.sol";

contract Strategy1Test is Test {
    using ECDSA for bytes32;

    IEntryPoint entryPoint;
    UpgradeableModularAccount account1;
    StrategyBuilderPlugin strategyBuilderPlugin;
    address owner1;
    uint256 owner1Key;
    address payable beneficiary;

    uint256 constant CALL_GAS_LIMIT = 800_000;
    uint256 constant VERIFICATION_GAS_LIMIT = 1000000;

    uint256 nonce = 0;

    FeeManagerMock feeManager;

    address public constant ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address public constant USDC = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address public constant WETH = 0x4200000000000000000000000000000000000006;

    //Fork Informations
    string BASE_MAINNET_FORK = vm.envString("BASE_MAINNET_FORK");
    uint256 baseFork;

    /**
     * Strategy 1 Staging Test:
     *  1. Fork the Base Chain
     *  2. Add Strategy Builder Plugin
     *  3. Add UniswapV2 Plugin
     *  4. Deploy the TimeCondition Contract
     *  5. Add Strategy
     *     5.1 StrategyStep without condition => Swap token x
     *  6. Execute Strategy
     *  7. Check if tokens were swapped
     */

    function setUp() public {
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

        // we will have a single function dependency for our counter contract: the single owner user op validation
        // we'll use this to ensure that only an owner can sign a user operation that can successfully increment
        FunctionReference[] memory dependencies = new FunctionReference[](1);
        dependencies[0] = FunctionReferenceLib.pack(
            address(singleOwnerPlugin), uint8(ISingleOwnerPlugin.FunctionId.USER_OP_VALIDATION_OWNER)
        );

        //Deploy a mock feeManager
        feeManager = new FeeManagerMock();

        strategyBuilderPlugin = new StrategyBuilderPlugin(address(feeManager));
        bytes32 manifestHash = keccak256(abi.encode(strategyBuilderPlugin.pluginManifest()));

        // install this plugin on the account as the owner
        vm.prank(owner1);
        account1.installPlugin({
            plugin: address(strategyBuilderPlugin),
            manifestHash: manifestHash,
            pluginInstallData: "0x",
            dependencies: dependencies
        });
    }
}
