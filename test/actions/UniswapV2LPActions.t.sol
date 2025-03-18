// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

import {UniswapV2LPActions} from "../../src/actions/uniswap-v2/UniswapV2LPActions.sol";
import {IAction} from "../../src/interfaces/IAction.sol";
import {IUniswapV2Base} from "../../src/actions/uniswap-v2/interfaces/IUniswapV2Base.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Token} from "../../src/test/mocks/MockToken.sol";

contract UniswapV2LPActionsTest is Test {
    error ExecutionFailed(IAction.PluginExecution execution);

    UniswapV2LPActions lpActions;

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

        lpActions = new UniswapV2LPActions(ROUTER);

        deal(TOKEN_HOLDER, MAX_ETH);
        vm.startPrank(TOKEN_HOLDER);
        token1 = new Token("Token 1","T1",MAX_TOKEN_SUPPLY);
        token2 = new Token("Token 2","T2",MAX_TOKEN_SUPPLY);

        vm.stopPrank();
    }

    function test_addLiquidity_AmountsDesiredNotZero(uint256 _amountADesired, uint256 _amountBDesired) external {
        uint256 amountADesired = bound(_amountADesired, 1e4, 1e24);
        uint256 amountBDesired = bound(_amountBDesired, 1e4, 1e24);

        deal(address(token1), WALLET, amountADesired);
        deal(address(token2), WALLET, amountBDesired);

        IAction.PluginExecution[] memory executions =
            lpActions.addLiquidity(address(token1), address(token2), amountADesired, amountBDesired, 0, 0, WALLET);

        execute(executions);

        address factory = IUniswapV2Router01(ROUTER).factory();
        address pair = IUniswapV2Factory(factory).getPair(address(token1), address(token2));

        (uint112 reserveToken1, uint112 reserveToken2,) = IUniswapV2Pair(pair).getReserves();

        assertEq(reserveToken1, amountADesired);
        assertEq(reserveToken2, amountBDesired);

        assertEq(token1.balanceOf(WALLET), 0);
        assertEq(token2.balanceOf(WALLET), 0);
        assertTrue(IERC20(pair).balanceOf(WALLET) > 0);
    }

    function test_addLiqudidity_BothAmountsEqualZero() external {
        uint256 amountADesired = 0;
        uint256 amountBDesired = 0;

        vm.expectRevert(IUniswapV2Base.NotZeroAmountForBothTokensAllowed.selector);

        lpActions.addLiquidity(address(token1), address(token2), amountADesired, amountBDesired, 0, 0, WALLET);
    }

    function test_addLiquidity_OneAmountDesiredEqualZero(uint256 _amountDesired, bool token1Zero) external {
        uint256 amountDesired = bound(_amountDesired, 1e4, 1e24);

        deal(address(token1), WALLET, amountDesired);
        deal(address(token2), WALLET, amountDesired);

        //Create the pool pair
        createLPPair();

        address factory = IUniswapV2Router01(ROUTER).factory();
        address pair = IUniswapV2Factory(factory).getPair(address(token1), address(token2));
        (uint112 reserveToken1, uint112 reserveToken2,) = IUniswapV2Pair(pair).getReserves();

        IAction.PluginExecution[] memory executions = lpActions.addLiquidity(
            address(token1),
            address(token2),
            token1Zero ? 0 : amountDesired,
            token1Zero ? amountDesired : 0,
            0,
            0,
            WALLET
        );

        execute(executions);

        (uint112 currentReserveToken1, uint112 currentReserveToken2,) = IUniswapV2Pair(pair).getReserves();

        assertEq(currentReserveToken1 - reserveToken1, amountDesired);
        assertEq(currentReserveToken2 - reserveToken2, amountDesired);

        assertEq(token1.balanceOf(WALLET), 0);
        assertEq(token2.balanceOf(WALLET), 0);
        assertTrue(IERC20(pair).balanceOf(WALLET) > 0);
    }

    function test_addLiqudityETH_AmountsDesiredNotZero(uint256 _amountETHDesired, uint256 _amountTokenDesired)
        external
    {
        uint256 amountETHDesired = bound(_amountETHDesired, 1e4, 1e24);
        uint256 amountTokenDesired = bound(_amountTokenDesired, 1e4, 1e24);

        deal(address(token1), WALLET, amountTokenDesired);
        deal(WALLET, amountETHDesired);

        IAction.PluginExecution[] memory executions =
            lpActions.addLiquidityETH(address(token1), amountTokenDesired, 0, amountETHDesired, 0, WALLET);

        execute(executions);

        address factory = IUniswapV2Router01(ROUTER).factory();

        address pair = IUniswapV2Factory(factory).getPair(address(token1), WETH);

        (uint112 reserveToken1, uint112 reserveToken2,) = IUniswapV2Pair(pair).getReserves();

        assertEq(reserveToken1, amountETHDesired);
        assertEq(reserveToken2, amountTokenDesired);

        assertEq(token1.balanceOf(WALLET), 0);
        assertEq(WALLET.balance, 0);
        assertTrue(IERC20(pair).balanceOf(WALLET) > 0);
    }

    function test_addLiquidityETH_OneAmountDesiredEqualZero(uint256 _amountDesired, bool tokenZero) external {
        uint256 amountDesired = bound(_amountDesired, 1e4, 1e24);

        deal(address(token1), WALLET, amountDesired);
        deal(WALLET, amountDesired);

        //Create the pool pair
        vm.startPrank(TOKEN_HOLDER);
        token1.approve(ROUTER, MAX_ETH / 2);

        IUniswapV2Router01(ROUTER).addLiquidityETH{value: MAX_ETH / 2}(
            address(token1), MAX_ETH / 2, 0, 0, TOKEN_HOLDER, block.timestamp + 10
        );
        vm.stopPrank();

        address factory = IUniswapV2Router01(ROUTER).factory();
        address pair = IUniswapV2Factory(factory).getPair(address(token1), WETH);
        (uint112 reserveToken1, uint112 reserveToken2,) = IUniswapV2Pair(pair).getReserves();

        IAction.PluginExecution[] memory executions = lpActions.addLiquidityETH(
            address(token1), tokenZero ? 0 : amountDesired, 0, tokenZero ? amountDesired : 0, 0, WALLET
        );

        execute(executions);

        (uint112 currentReserveToken1, uint112 currentReserveToken2,) = IUniswapV2Pair(pair).getReserves();

        assertEq(currentReserveToken1 - reserveToken1, amountDesired);
        assertEq(currentReserveToken2 - reserveToken2, amountDesired);

        assertEq(token1.balanceOf(WALLET), 0);
        assertEq(WALLET.balance, 0);
        assertTrue(IERC20(pair).balanceOf(WALLET) > 0);
    }

    function test_addLiqudidityETH_BothAmountsEqualZero() external {
        uint256 amountTokenDesired = 0;
        uint256 amountETHDesired = 0;

        vm.expectRevert(IUniswapV2Base.NotZeroAmountForBothTokensAllowed.selector);

        lpActions.addLiquidityETH(address(token1), amountTokenDesired, 0, amountETHDesired, 0, WALLET);
    }

    function test_removeLiquidity_Success(uint256 _amount) external {
        //add liquidity
        uint256 amountDesired = 10e19;
        deal(address(token1), WALLET, amountDesired);
        deal(address(token2), WALLET, amountDesired);

        IAction.PluginExecution[] memory lpAddExecutions =
            lpActions.addLiquidity(address(token1), address(token2), amountDesired, amountDesired, 0, 0, WALLET);

        execute(lpAddExecutions);

        address factory = IUniswapV2Router01(ROUTER).factory();
        address pair = IUniswapV2Factory(factory).getPair(address(token1), address(token2));
        uint256 liquidityBalance = IERC20(pair).balanceOf(WALLET);

        uint256 liqudity = bound(_amount, 1e2, liquidityBalance);

        IAction.PluginExecution[] memory executions =
            lpActions.removeLiquidity(address(token1), address(token2), liqudity, 0, 0, WALLET);

        execute(executions);

        assertEq(liquidityBalance - liqudity, IERC20(pair).balanceOf(WALLET));
    }

    function test_removeLiqudityETH_Success() external {
        assertTrue(false);
    }

    function test_addLiquidityPercentage_Success(uint256 _percentage, uint256 _balanceToken1, uint256 _balanceToken2)
        external
    {
        uint256 percentage = bound(_percentage, 1, lpActions.PERCENTAGE_FACTOR());

        uint256 balanceToken1 = bound(_balanceToken1, 0.01 ether, 200 ether);
        uint256 balanceToken2 = bound(_balanceToken2, 0.01 ether, 200 ether);

        deal(address(token1), WALLET, balanceToken1);
        deal(address(token2), WALLET, balanceToken2);

        //createLP
        createLPPair();

        // Act
        IAction.PluginExecution[] memory executions =
            lpActions.addLiqudityPercentage(address(token1), address(token2), percentage, WALLET);

        execute(executions);

        //Assert
        address factory = IUniswapV2Router01(ROUTER).factory();
        address pair = IUniswapV2Factory(factory).getPair(address(token1), address(token2));
        (uint112 reserveToken1, uint112 reserveToken2,) = IUniswapV2Pair(pair).getReserves();

        uint256 maxAmountA = balanceToken1;
        uint256 maxAmountB = balanceToken2;

        uint256 requiredB = (balanceToken1 * reserveToken2) / reserveToken1;

        if (requiredB > balanceToken2) {
            maxAmountA = (balanceToken2 * reserveToken1) / reserveToken2;
        } else {
            maxAmountB = requiredB;
        }
        uint256 expToken2 = (balanceToken2 - (maxAmountB * percentage / lpActions.PERCENTAGE_FACTOR()));
        uint256 expToken1 = (balanceToken1 - (maxAmountA * percentage / lpActions.PERCENTAGE_FACTOR()));
        assertEq(expToken2, IERC20(token2).balanceOf(WALLET));
        assertEq(expToken1, IERC20(token1).balanceOf(WALLET));

        assertTrue(IERC20(pair).balanceOf(WALLET) > 0);
    }

    function test_addLiquidityPercentageETH(uint256 _percentage, uint256 _balanceToken, uint256 _balanceETH) external {
        uint256 percentage = bound(_percentage, 1, lpActions.PERCENTAGE_FACTOR());

        uint256 balanceToken = bound(_balanceToken, 0.01 ether, 200 ether);
        uint256 balanceETH = bound(_balanceETH, 0.01 ether, 200 ether);

        deal(address(token1), WALLET, balanceToken);
        deal(WALLET, balanceETH);

        //createLP
        createLPPairETH();

        //Act
        // Act
        IAction.PluginExecution[] memory executions =
            lpActions.addLiqudityPercentageETH(address(token1), percentage, WALLET);

        execute(executions);

        //Assert
        address factory = IUniswapV2Router01(ROUTER).factory();
        address pair = IUniswapV2Factory(factory).getPair(address(token1), WETH);
        (uint112 reserveA, uint112 reserveB,) = IUniswapV2Pair(pair).getReserves();

        uint112 reserveToken;
        uint112 reserveETH;
        if (IUniswapV2Pair(pair).token0() == address(token1)) {
            reserveToken = reserveA;
            reserveETH = reserveB;
        } else {
            reserveToken = reserveB;
            reserveETH = reserveA;
        }
        uint256 maxAmountToken = balanceToken;
        uint256 maxAmountETH = balanceETH;

        uint256 requiredETH = (balanceToken * reserveETH) / reserveToken;

        if (requiredETH > balanceETH) {
            maxAmountToken = (balanceETH * reserveToken) / reserveETH;
        } else {
            maxAmountETH = requiredETH;
        }

        uint256 expETH = (balanceETH - (maxAmountETH * percentage / lpActions.PERCENTAGE_FACTOR()));
        uint256 expToken = (balanceToken - (maxAmountToken * percentage / lpActions.PERCENTAGE_FACTOR()));

        assertTrue(isApproximatelyEqual(expToken, IERC20(token1).balanceOf(WALLET), 100));
        assertTrue(isApproximatelyEqual(expETH, WALLET.balance, 100));

        assertTrue(IERC20(pair).balanceOf(WALLET) > 0);
    }

    function test_removeLiqudityPercentage_Success(uint256 _percentage) external {
        uint256 percentage = bound(_percentage, 1, lpActions.PERCENTAGE_FACTOR());
        //Add liqudity
        uint256 amountADesired = 1e24;
        uint256 amountBDesired = 1e24;

        deal(address(token1), WALLET, amountADesired);
        deal(address(token2), WALLET, amountBDesired);

        IAction.PluginExecution[] memory addLPExecutions =
            lpActions.addLiquidity(address(token1), address(token2), amountADesired, amountBDesired, 0, 0, WALLET);

        execute(addLPExecutions);

        address factory = IUniswapV2Router01(ROUTER).factory();
        address pair = IUniswapV2Factory(factory).getPair(address(token1), address(token2));

        uint256 liquidity = IERC20(pair).balanceOf(WALLET);

        //Act
        IAction.PluginExecution[] memory executions =
            lpActions.removeLiquidityPercentage(address(token1), address(token2), percentage, WALLET);
        execute(executions);

        uint256 expLiquidity = liquidity - liquidity * percentage / lpActions.PERCENTAGE_FACTOR();

        assertTrue(isApproximatelyEqual(expLiquidity, IERC20(pair).balanceOf(WALLET), 100));
    }

    function test_removeLiquidityPercentageETH_Success(uint256 _percentage) external {
        uint256 percentage = bound(_percentage, 1, lpActions.PERCENTAGE_FACTOR());
        //Add liqudity
        uint256 amountTokenDesired = 1e24;
        uint256 amountETHDesired = 1e24;

        deal(address(token1), WALLET, amountTokenDesired);
        deal(WALLET, amountETHDesired);

        IAction.PluginExecution[] memory addLPExecutions =
            lpActions.addLiquidityETH(address(token1), amountTokenDesired, 0, amountETHDesired, 0, WALLET);

        execute(addLPExecutions);

        address factory = IUniswapV2Router01(ROUTER).factory();
        address pair = IUniswapV2Factory(factory).getPair(address(token1), WETH);

        uint256 liquidity = IERC20(pair).balanceOf(WALLET);

        //Act

        IAction.PluginExecution[] memory executions =
            lpActions.removeLiquidityETHPercentage(address(token1), percentage, WALLET);
        execute(executions);

        uint256 expLiquidity = liquidity - liquidity * percentage / lpActions.PERCENTAGE_FACTOR();

        assertTrue(isApproximatelyEqual(expLiquidity, IERC20(pair).balanceOf(WALLET), 100));
    }

    function test_zap_Success(uint256 _amountIn) external {
        uint256 amountIn = bound(_amountIn, 1e5, MAX_TOKEN_SUPPLY / 10);
        deal(address(token1), WALLET, amountIn);

        createLPPair();

        //Act
        IAction.PluginExecution[] memory executions = lpActions.zap(address(token1), address(token2), amountIn, WALLET);
        execute(executions);

        assertTrue(isApproximatelyEqual(IERC20(address(token1)).balanceOf(WALLET), 0, 10));
    }

    function test_zapETH_InputETH_Success(uint256 _amountIn) external {
        createLPPairETH();

        bool inputETH = true;

        uint256 amountIn = bound(_amountIn, 1e5, MAX_ETH / 10);
        // uint256 amountIn = 1e18;

        deal(WALLET, amountIn);

        //Act
        IAction.PluginExecution[] memory executions = lpActions.zapETH(address(token1), amountIn, inputETH, WALLET);
        execute(executions);

        assertTrue(isApproximatelyEqual(WALLET.balance, 0, 10));

        address factory = IUniswapV2Router01(ROUTER).factory();
        address pair = IUniswapV2Factory(factory).getPair(address(token1), WETH);

        uint256 liquidity = IERC20(pair).balanceOf(WALLET);

        assertTrue(liquidity > 0);
    }

    function test_zapETH_InputToken_Success(uint256 _amountIn) external {
        createLPPairETH();

        bool inputETH = false;

        uint256 amountIn = bound(_amountIn, 1e5, MAX_ETH / 10);
        // uint256 amountIn = 1e18;

        deal(address(token1), WALLET, amountIn);

        //Act
        IAction.PluginExecution[] memory executions = lpActions.zapETH(address(token1), amountIn, inputETH, WALLET);
        execute(executions);

        assertTrue(isApproximatelyEqual(IERC20(address(token1)).balanceOf(WALLET), 0, 10));

        address factory = IUniswapV2Router01(ROUTER).factory();
        address pair = IUniswapV2Factory(factory).getPair(address(token1), WETH);

        uint256 liquidity = IERC20(pair).balanceOf(WALLET);

        assertTrue(liquidity > 0);
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

    function createLPPair() internal {
        //Create the pool pair
        vm.startPrank(TOKEN_HOLDER);
        token1.approve(ROUTER, MAX_TOKEN_SUPPLY / 2);
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
        vm.stopPrank();
    }

    function createLPPairETH() internal {
        //Create the pool pair
        vm.startPrank(TOKEN_HOLDER);
        token1.approve(ROUTER, MAX_ETH / 2);

        IUniswapV2Router01(ROUTER).addLiquidityETH{value: MAX_ETH}(
            address(token1), MAX_ETH / 2, 0, 0, TOKEN_HOLDER, block.timestamp + 10
        );
        vm.stopPrank();
    }

    function isApproximatelyEqual(uint256 target, uint256 current, uint256 tolerance) public pure returns (bool) {
        if (target > current) {
            return (target - current) <= tolerance;
        } else {
            return (current - target) <= tolerance;
        }
    }
}
