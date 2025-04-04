// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {UniswapV2SwapActions} from "../../src/actions/uniswap-v2/UniswapV2SwapActions.sol";
import {IAction} from "../../src/interfaces/IAction.sol";
import {IUniswapV2Base} from "../../src/actions/uniswap-v2/interfaces/IUniswapV2Base.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";

import {Token} from "../../src/test/mocks/MockToken.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapV2SwapActionsTest is Test {
    error ExecutionFailed(IAction.PluginExecution execution);

    UniswapV2SwapActions swapActions;

    address public constant ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; //Aerodrome Router
    // address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    // address public constant TOKEN_1 = 0x8e306E02ec1EFFC4fDAd3f952fbEEebf3730ae19;

    Token token1;
    Token token2;

    address public TOKEN_HOLDER = makeAddr("token-holder");

    uint256 public constant MAX_TOKEN_SUPPLY = 1_000_000 * 1e18;
    uint256 public constant MAX_ETH = 100 ether;

    string BASE_MAINNET_FORK = vm.envString("BASE_MAINNET_FORK");
    uint256 baseFork;

    address WALLET = makeAddr("wallet");

    function setUp() external {
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
    }

    function test_swapExactTokensForTokens_Success(uint256 amountIn) external {
        uint256 bndAmountIn = bound(amountIn, 10, MAX_TOKEN_SUPPLY / 4);

        deal(address(token1), WALLET, bndAmountIn);

        uint256 balanceBefore = IERC20(address(token1)).balanceOf(WALLET);

        IAction.PluginExecution[] memory executions =
            swapActions.swapExactTokensForTokens(bndAmountIn, 0, getPath(), WALLET);

        execute(executions);

        assertEq(IERC20(address(token1)).balanceOf(WALLET) + bndAmountIn, balanceBefore);

        assert(IERC20(address(token2)).balanceOf(WALLET) > 0);
    }

    function test_swapExactTokensForTokens_ZeroAmount() external {
        vm.expectRevert(IUniswapV2Base.NoZeroAmountValid.selector);
        swapActions.swapExactTokensForTokens(0, 0, getPath(), WALLET);
    }

    function test_swapTokensForExactTokens_Success(uint256 amountOut) external {
        uint256 bndAmountOut = bound(amountOut, 1e18, MAX_TOKEN_SUPPLY / 10);

        deal(address(token1), WALLET, MAX_TOKEN_SUPPLY / 2);

        uint256 balanceBefore = IERC20(address(token1)).balanceOf(WALLET);

        IAction.PluginExecution[] memory executions =
            swapActions.swapTokensForExactTokens(bndAmountOut, 0, getPath(), WALLET);

        execute(executions);

        assert(IERC20(address(token1)).balanceOf(WALLET) < balanceBefore);

        assertEq(IERC20(address(token2)).balanceOf(WALLET), bndAmountOut);
    }

    function test_swapTokensForExactTokens_MaxAmountIn(uint256 amountOut) external {
        uint256 bndAmountOut = bound(amountOut, 1e18, MAX_TOKEN_SUPPLY / 10);

        deal(address(token1), WALLET, MAX_TOKEN_SUPPLY / 2);

        uint256 balanceBefore = IERC20(address(token1)).balanceOf(WALLET);

        IAction.PluginExecution[] memory executions =
            swapActions.swapTokensForExactTokens(bndAmountOut, balanceBefore, getPath(), WALLET);

        execute(executions);

        assert(IERC20(address(token1)).balanceOf(WALLET) < balanceBefore);

        assertEq(IERC20(address(token2)).balanceOf(WALLET), bndAmountOut);
    }

    function test_swapExactETHForTokens_Success(uint256 amountIn) external {
        uint256 bndAmountIn = bound(amountIn, 0.1 ether, MAX_ETH / 4);

        deal(WALLET, bndAmountIn);

        uint256 balanceBefore = WALLET.balance;

        IAction.PluginExecution[] memory executions =
            swapActions.swapExactETHForTokens(bndAmountIn, 0, getPathETHIn(), WALLET);

        execute(executions);

        assertEq(WALLET.balance + bndAmountIn, balanceBefore);

        assert(IERC20(address(token1)).balanceOf(WALLET) > 0);
    }

    function test_swapTokensForExactETH_Success(uint256 amountOut) external {
        uint256 bndAmountOut = bound(amountOut, 0.1 ether, MAX_ETH / 4);

        deal(address(token1), WALLET, MAX_TOKEN_SUPPLY / 2);

        uint256 balanceBefore = IERC20(address(token1)).balanceOf(WALLET);

        IAction.PluginExecution[] memory executions =
            swapActions.swapTokensForExactETH(bndAmountOut, 0, getPathETHOut(), WALLET);

        execute(executions);

        assertEq(WALLET.balance, bndAmountOut);
        assert(IERC20(address(token1)).balanceOf(WALLET) < balanceBefore);
    }

    function test_swapTokensForExactETH_MaxAmountIn(uint256 amountOut) external {
        uint256 bndAmountOut = bound(amountOut, 0.1 ether, MAX_ETH / 4);

        deal(address(token1), WALLET, MAX_TOKEN_SUPPLY / 2);

        uint256 balanceBefore = IERC20(address(token1)).balanceOf(WALLET);

        IAction.PluginExecution[] memory executions =
            swapActions.swapTokensForExactETH(bndAmountOut, balanceBefore, getPathETHOut(), WALLET);

        execute(executions);

        assertEq(WALLET.balance, bndAmountOut);
        assert(IERC20(address(token1)).balanceOf(WALLET) < balanceBefore);
    }

    function test_swapExactTokensForETH_Success(uint256 amountIn) external {
        uint256 bndAmountIn = bound(amountIn, 1e18, MAX_TOKEN_SUPPLY / 4);

        deal(address(token1), WALLET, bndAmountIn);

        uint256 balanceBefore = IERC20(address(token1)).balanceOf(WALLET);

        IAction.PluginExecution[] memory executions =
            swapActions.swapExactTokensForETH(bndAmountIn, 0, getPathETHOut(), WALLET);

        execute(executions);

        assert(WALLET.balance > 0);
        assertEq(IERC20(address(token1)).balanceOf(WALLET), balanceBefore - bndAmountIn);
    }

    function test_swapETHForExactTokens_Success(uint256 amountOut) external {
        uint256 bndAmountOut = bound(amountOut, 1e18, MAX_TOKEN_SUPPLY / 10);

        deal(WALLET, MAX_ETH);

        uint256 balanceBefore = WALLET.balance;

        IAction.PluginExecution[] memory executions =
            swapActions.swapETHForExactTokens(bndAmountOut, 0, getPathETHIn(), WALLET);

        execute(executions);

        assert(WALLET.balance < balanceBefore);

        assertEq(IERC20(address(token1)).balanceOf(WALLET), bndAmountOut);
    }

    function test_swapETHForExactTokens_MaxAmountIn(uint256 amountOut) external {
        uint256 bndAmountOut = bound(amountOut, 1e18, MAX_TOKEN_SUPPLY / 10);

        deal(WALLET, MAX_ETH);

        uint256 balanceBefore = WALLET.balance;

        IAction.PluginExecution[] memory executions =
            swapActions.swapETHForExactTokens(bndAmountOut, balanceBefore, getPathETHIn(), WALLET);

        execute(executions);

        assert(WALLET.balance < balanceBefore);

        assertEq(IERC20(address(token1)).balanceOf(WALLET), bndAmountOut);
    }

    function test_swapPercentageTokensForTokens_Success(uint256 percentage) external {
        uint256 bndPercentage = bound(percentage, 1, swapActions.PERCENTAGE_FACTOR());

        uint256 tokenBalance = MAX_TOKEN_SUPPLY / 10;

        deal(address(token1), WALLET, tokenBalance);

        IAction.PluginExecution[] memory executions =
            swapActions.swapPercentageTokensForTokens(bndPercentage, getPath(), WALLET);

        execute(executions);

        uint256 expAmountIn = (bndPercentage * tokenBalance) / swapActions.PERCENTAGE_FACTOR();

        assertEq(IERC20(address(token1)).balanceOf(WALLET), tokenBalance - expAmountIn);
        assert(IERC20(address(token2)).balanceOf(WALLET) > 0);
    }

    function test_swapPercentageTokensForETH_Success(uint256 percentage) external {
        uint256 bndPercentage = bound(percentage, 1, swapActions.PERCENTAGE_FACTOR());

        uint256 tokenBalance = MAX_TOKEN_SUPPLY / 10;

        deal(address(token1), WALLET, tokenBalance);

        IAction.PluginExecution[] memory executions =
            swapActions.swapPercentageTokensForETH(bndPercentage, getPathETHOut(), WALLET);

        execute(executions);

        uint256 expAmountIn = (bndPercentage * tokenBalance) / swapActions.PERCENTAGE_FACTOR();

        assertEq(IERC20(address(token1)).balanceOf(WALLET), tokenBalance - expAmountIn);

        assert(WALLET.balance > 0);
    }

    function test_swapPercentageETHForTokens(uint256 percentage) external {
        uint256 bndPercentage = bound(percentage, 1, swapActions.PERCENTAGE_FACTOR());

        uint256 balanceETH = MAX_ETH;

        deal(WALLET, balanceETH);

        IAction.PluginExecution[] memory executions =
            swapActions.swapPercentageETHForTokens(bndPercentage, getPathETHIn(), WALLET);

        execute(executions);

        uint256 expAmountIn = (bndPercentage * balanceETH) / swapActions.PERCENTAGE_FACTOR();

        assertEq(WALLET.balance, balanceETH - expAmountIn);

        assert(IERC20(address(token1)).balanceOf(WALLET) > 0);
    }

    function test_getTokenForSelector_TokenGetterID_1() external {
        bytes4 selector = UniswapV2SwapActions.swapETHForExactTokens.selector;

        bytes memory params = abi.encode(uint256(1e18), uint256(0), getPathETHIn(), WALLET);

        address token = swapActions.getTokenForSelector(selector, params);

        assertEq(token, address(0));
    }

    function test_getTokenForSelector_TokenGetterID_2() external {
        bytes4 selector = UniswapV2SwapActions.swapExactTokensForETH.selector;

        bytes memory params = abi.encode(uint256(1e18), uint256(0), getPathETHOut(), WALLET);

        address token = swapActions.getTokenForSelector(selector, params);

        assertEq(token, address(token1));
    }

    function test_getTokenForSelector_TokenGetterID_3() external {
        bytes4 selector = UniswapV2SwapActions.swapPercentageTokensForETH.selector;

        bytes memory params = abi.encode(uint256(1e18), getPathETHOut(), WALLET);

        address token = swapActions.getTokenForSelector(selector, params);

        assertEq(token, address(token1));
    }

    function test_getTokenForSelector_InvalidTokenGetter() external {
        bytes4 selector = bytes4(keccak256(bytes("invalid-function")));

        bytes memory params = abi.encode(uint256(1e18), uint256(0), getPathETHOut(), WALLET);

        vm.expectRevert(IUniswapV2Base.InvalidTokenGetterID.selector);
        swapActions.getTokenForSelector(selector, params);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       HELPER         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━┛

    function execute(IAction.PluginExecution[] memory executions) internal {
        for (uint256 i = 0; i < executions.length; i++) {
            IAction.PluginExecution memory execution = executions[i];

            vm.prank(WALLET);
            (bool success,) = payable(execution.target).call{value: execution.value}(execution.data);
            if (!success) {
                revert ExecutionFailed(execution);
            }
        }
    }

    function getPathETHIn() internal view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(token1);

        return path;
    }

    function getPathETHOut() internal view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[1] = WETH;
        path[0] = address(token1);

        return path;
    }

    function getPath() internal view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);

        return path;
    }
}
