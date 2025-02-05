// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UniswapV2Base} from "./UniswapV2Base.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapV2SwapBaseActions is UniswapV2Base {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    constructor(address _router) UniswapV2Base(_router) {}

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃  Base Swap PluginExecution Functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to)
        public
        view
        nonZeroAmount(amountIn)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);
        executions[0] = _approveToken(path[0], amountIn);

        executions[1] = _swapExactTokensForTokens(amountIn, amountOutMin, path, to, _deadline());
        return executions;
    }

    function swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to)
        public
        view
        nonZeroAmount(amountOut)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);
        executions[0] = _approveToken(path[0], amountInMax);

        executions[1] = _swapTokensForExactTokens(amountOut, amountInMax, path, to, _deadline());

        return executions;
    }

    function swapExactETHForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to)
        public
        view
        nonZeroAmount(amountIn)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](1);
        executions[0] = _swapExactETHForTokens(amountIn, amountOutMin, path, to, _deadline());
    }

    function swapTokensForExactETH(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to)
        public
        view
        nonZeroAmount(amountOut)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _approveToken(path[0], amountInMax);

        executions[1] = _swapTokensForExactETH(amountOut, amountInMax, path, to, _deadline());

        return executions;
    }

    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to)
        public
        view
        nonZeroAmount(amountIn)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);
        executions[0] = _approveToken(path[0], amountIn);

        executions[1] = _swapExactTokensForETH(amountIn, amountOutMin, path, to, _deadline());

        return executions;
    }

    function swapETHForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to)
        public
        view
        nonZeroAmount(amountOut)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](1);

        if (amountInMax == 0) {
            amountInMax = _getMaxAmountIn(path, amountOut);
        }

        executions[0] = _swapETHForExactTokens(amountInMax, amountOut, path, msg.sender, _deadline());

        return executions;
    }

    // /* ====== Percentage Swap Functions ====== */

    // function swapPercentageTokensForTokens(uint256 percentage, address[] calldata path)
    //     external
    //     validPercentage(percentage)
    // {
    //     // swapExactTokensForTokens(_percentageShare(path[0], percentage), 0, path);
    // }

    // function swapPercentageTokensForETH(uint256 percentage, address[] calldata path)
    //     external
    //     validPercentage(percentage)
    // {
    //     // swapExactTokensForETH(_percentageShare(path[0], percentage), 0, path);
    // }

    // function swapPercentageETHForTokens(uint256 percentage, address[] calldata path)
    //     external
    //     validPercentage(percentage)
    // {
    //     // swapExactETHForTokens(_percentageShareETH(percentage), 0, path);
    // }

    // /* ====== Percentage LP Functions ====== */

    // function addLiquidityETHPercentage(address token, uint256 percentageETHDesired)
    //     public
    //     validPercentage(percentageETHDesired)
    // {
    //     // uint256 amountETHDesired = _percentageShareETH(percentageETHDesired);

    //     // uint256 amountTokenDesired =
    //     //     _calculateAmountForLP(router.WETH(), amountETHDesired, _getPoolPair(token, router.WETH()));

    //     // addLiquidityETH(token, amountTokenDesired, 0, amountETHDesired, 0);
    // }

    // function addLiquidityETHPercentageToken(address token, uint256 percentageTokenDesired)
    //     external
    //     validPercentage(percentageTokenDesired)
    // {
    //     // uint256 amountTokenDesired = _percentageShare(token, percentageTokenDesired);
    //     // uint256 amountETHDesired = _calculateAmountForLP(token, amountTokenDesired, _getPoolPair(token, router.WETH()));

    //     // addLiquidityETH(token, amountTokenDesired, 0, amountETHDesired, 0);
    // }

    // function addLiquidityPercentage(uint256 percentageADesired, address tokenA, address tokenB)
    //     external
    //     validPercentage(percentageADesired)
    // {
    //     // uint256 amountADesired = _percentageShare(tokenA, percentageADesired);
    //     // uint256 amountBDesired = _calculateAmountForLP(tokenA, amountADesired, _getPoolPair(tokenA, tokenB));

    //     // _approveToken(tokenA, amountADesired);
    //     // _approveToken(tokenB, amountBDesired);

    //     // (uint256 amountA, uint256 amountB, uint256 liquidity) = msg.sender.addLiquidity(
    //     //     address(router), tokenA, tokenB, amountADesired, amountBDesired, 0, 0, msg.sender, _deadline()
    //     // );

    //     // emit LiquidityAdded(tokenA, tokenB, amountA, amountB, liquidity);
    // }

    // function addLiqudityPercentageOfMaxPossible(address tokenA, address tokenB, uint256 percentage)
    //     external
    //     validPercentage(percentage)
    // {
    //     // address pair = _getPoolPair(tokenA, tokenB);

    //     // address _tokenA = tokenA;
    //     // address _tokenB = tokenB;
    //     // if (IUniswapV2Pair(pair).token0() != tokenA) {
    //     //     _tokenA = tokenB;
    //     //     _tokenB = tokenA;
    //     // }

    //     // (uint256 maxAmountA, uint256 maxAmountB) = _calculateMaxAmounts(_tokenA, _tokenB, pair);

    //     // uint256 percentageAmountA = (maxAmountA * percentage) / PERCENTAGE_FACTOR;
    //     // uint256 percentageAmountB = (maxAmountB * percentage) / PERCENTAGE_FACTOR;

    //     // addLiquidity(_tokenA, _tokenB, percentageAmountA, percentageAmountB, 0, 0);
    // }

    // function removeLiquidityETHPercentage(address token, uint256 liquidityPercentage)
    //     external
    //     validPercentage(liquidityPercentage)
    // {
    //     // removeLiquidityETH(token, _percentageShare(_getPoolPair(token, router.WETH()), liquidityPercentage), 0, 0);
    // }

    // function removeLiquidityPercentage(address tokenA, address tokenB, uint256 percentageLiquidity)
    //     external
    //     validPercentage(percentageLiquidity)
    // {
    //     // removeLiquidity(tokenA, tokenB, _percentageShare(_getPoolPair(tokenA, tokenB), percentageLiquidity), 0, 0);
    // }

    // function zap(address tokenA, address tokenB, uint256 amountIn) external {
    //     // address pair = _getPoolPair(tokenA, tokenB);

    //     // uint256 swapAmount = _calculateSwapAmountForProvidingLiquidity(pair, tokenA, amountIn);

    //     // uint256 amountTokenB = _swap(tokenA, tokenB, swapAmount);
    //     // addLiquidity(tokenA, tokenB, amountIn - swapAmount, amountTokenB, 0, 0);
    // }

    // function zapETH(address token, uint256 amountIn, bool inputETH) external {
    //     // address WETH = router.WETH();
    //     // address pair = _getPoolPair(WETH, token);

    //     // address tokenA = inputETH ? WETH : token;

    //     // uint256 swapAmount = _calculateSwapAmountForProvidingLiquidity(pair, tokenA, amountIn);

    //     // uint256 amountToken;
    //     // uint256 amountETH;
    //     // if (inputETH) {
    //     //     amountToken = _swapETH(token, swapAmount);
    //     //     amountETH = amountIn - swapAmount;
    //     // } else {
    //     //     amountETH = _swapToETH(token, swapAmount);
    //     //     amountToken = amountIn - swapAmount;
    //     // }

    //     // addLiquidityETH(token, amountToken, 0, amountETH, 0);
    // }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Internal Functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    // function _deadline() internal view returns (uint256) {
    //     return block.timestamp + DELTA_DEADLINE;
    // }

    // function _percentageShare(address token, uint256 percentage) internal view returns (uint256) {
    //     uint256 totalTokenAmount = IERC20(token).balanceOf(msg.sender);
    //     return (percentage * totalTokenAmount) / PERCENTAGE_FACTOR;
    // }

    // function _percentageShareETH(uint256 percentage) internal view returns (uint256) {
    //     uint256 totalBalanceETH = msg.sender.balance;
    //     return (totalBalanceETH * percentage) / PERCENTAGE_FACTOR;
    // }

    // function _calculateMaxAmounts(address tokenA, address tokenB, address pair)
    //     internal
    //     returns (uint256 maxAmountA, uint256 maxAmountB)
    // {
    //     (uint112 reserveA, uint112 reserveB,) = IUniswapV2Pair(pair).getReserves();

    //     uint256 balanceTokenA = IERC20(tokenA).balanceOf(msg.sender);
    //     uint256 balanceTokenB = IERC20(tokenB).balanceOf(msg.sender);

    //     maxAmountA = balanceTokenA;
    //     maxAmountB = balanceTokenB;

    //     uint256 requiredB = (balanceTokenA * reserveB) / reserveA;

    //     if (requiredB > balanceTokenB) {
    //         maxAmountA = (balanceTokenB * reserveA) / reserveB;
    //     } else {
    //         maxAmountB = requiredB;
    //     }
    // }

    // function _calculateAmountForLP(address token, uint256 amount, address poolPair)
    //     internal
    //     view
    //     returns (uint256 amountForLp)
    // {
    //     address token0 = IUniswapV2Pair(poolPair).token0();
    //     (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(poolPair).getReserves();

    //     if (token0 == token) {
    //         amountForLp = (amount * reserve1) / reserve0;
    //     } else {
    //         amountForLp = (amount * reserve0) / reserve1;
    //     }
    // }

    // function _getPoolPair(address tokenA, address tokenB) internal view returns (address) {
    //     address _factory = IUniswapV2Router01(router).factory();
    //     address _poolPair = IUniswapV2Factory(_factory).getPair(tokenA, tokenB);

    //     if (_poolPair == address(0)) {
    //         revert UniswapV2Base__PoolPairDoesNotExist();
    //     }

    //     return _poolPair;
    // }

    // function _getMaxAmountIn(address[] memory path, uint256 amountOut) internal view returns (uint256) {
    //     return IUniswapV2Router01(router).getAmountsIn(amountOut, path)[0];
    // }

    function _swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal view returns (PluginExecution memory) {
        bytes memory _data =
            abi.encodeCall(IUniswapV2Router01.swapExactTokensForTokens, (amountIn, amountOutMin, path, to, deadline));

        return PluginExecution({target: router, value: 0, data: _data});
    }

    function _swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal view returns (PluginExecution memory) {
        bytes memory _data =
            abi.encodeCall(IUniswapV2Router01.swapExactTokensForETH, (amountIn, amountOutMin, path, to, deadline));

        return PluginExecution({target: router, value: 0, data: _data});
    }

    function _swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal view returns (PluginExecution memory) {
        bytes memory _data =
            abi.encodeCall(IUniswapV2Router01.swapTokensForExactTokens, (amountOut, amountInMax, path, to, deadline));

        return PluginExecution({target: router, value: 0, data: _data});
    }

    function _swapExactETHForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal view returns (PluginExecution memory) {
        bytes memory _data =
            abi.encodeCall(IUniswapV2Router01.swapExactETHForTokens, (amountOutMin, path, to, deadline));

        return PluginExecution({target: router, value: amountIn, data: _data});
    }

    function _swapETHForExactTokens(
        uint256 amountInMax,
        uint256 amountOut,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(IUniswapV2Router01.swapETHForExactTokens, (amountOut, path, to, deadline));

        return PluginExecution({target: router, value: amountInMax, data: _data});
    }

    function _swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal view returns (PluginExecution memory) {
        bytes memory _data =
            abi.encodeCall(IUniswapV2Router01.swapTokensForExactETH, (amountOut, amountInMax, path, to, deadline));

        return PluginExecution({target: router, value: 0, data: _data});
    }
}
