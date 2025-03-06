// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {UniswapV2SwapActions} from "../../src/actions/uniswap-v2/UniswapV2SwapActions.sol";

contract UniswapV2PluginTest is Test {
    address public constant ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; //Aerodrome Router
    address public constant USDC = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address public constant WETH = 0x4200000000000000000000000000000000000006;

    string BASE_MAINNET_FORK = vm.envString("BASE_MAINNET_FORK");
    uint256 baseFork;

    function setUp() external {
        //Fork the base chain
        baseFork = vm.createFork(BASE_MAINNET_FORK);
        vm.selectFork(baseFork);
    }
}
