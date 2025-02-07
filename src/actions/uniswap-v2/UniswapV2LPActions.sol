// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UniswapV2Base} from "./UniswapV2Base.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error UniswapV2LPActions__PoolPairDoesNotExist();
error UniswapV2LPActions__NotZeroAmountForBothTokensAllowed();

contract UniswapV2LPActions is UniswapV2Base {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    constructor(address _router) UniswapV2Base(_router) {}

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Base LP PluginExecution Functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) public view returns (PluginExecution[] memory) {
        if (amountADesired == 0 && amountBDesired == 0) {
            revert UniswapV2LPActions__NotZeroAmountForBothTokensAllowed();
        }

        if (amountADesired == 0) {
            amountADesired = _calculateAmountForLP(tokenB, amountBDesired, _getPoolPair(tokenA, tokenB));
        }

        if (amountBDesired == 0) {
            amountBDesired = _calculateAmountForLP(tokenA, amountADesired, _getPoolPair(tokenA, tokenB));
        }

        PluginExecution[] memory executions = new PluginExecution[](3);

        executions[0] = _approveToken(tokenA, amountADesired);
        executions[1] = _approveToken(tokenB, amountBDesired);

        executions[2] =
            _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to, _deadline());

        return executions;
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHDesired,
        uint256 amountETHMin,
        address to
    ) public view returns (PluginExecution[] memory) {
        if (amountTokenDesired == 0 && amountETHDesired == 0) {
            revert UniswapV2LPActions__NotZeroAmountForBothTokensAllowed();
        }

        if (amountTokenDesired == 0) {
            amountTokenDesired = _calculateAmountForLP(WETH, amountETHDesired, _getPoolPair(token, WETH));
        }

        if (amountETHDesired == 0) {
            amountETHDesired = _calculateAmountForLP(token, amountTokenDesired, _getPoolPair(token, WETH));
        }

        PluginExecution[] memory executions = new PluginExecution[](2);
        executions[0] = _approveToken(token, amountTokenDesired);

        executions[1] =
            _addLiquidityETH(token, amountETHDesired, amountTokenDesired, amountTokenMin, amountETHMin, to, _deadline());

        return executions;
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) public view nonZeroAmount(liquidity) returns (PluginExecution[] memory) {
        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _approveToken(_getPoolPair(tokenA, tokenB), liquidity);

        executions[1] = _removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, _deadline());

        return executions;
    }

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to
    ) public view nonZeroAmount(liquidity) returns (PluginExecution[] memory) {
        PluginExecution[] memory executions = new PluginExecution[](2);
        executions[0] = _approveToken(_getPoolPair(token, WETH), liquidity);

        executions[1] = _removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, _deadline());

        return executions;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Percentage LP PluginExecution Functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function addLiquidityETHPercentage(address token, uint256 percentageETHDesired, address to)
        public
        view
        validPercentage(percentageETHDesired)
        returns (PluginExecution[] memory)
    {
        uint256 amountETHDesired = _percentageShareETH(percentageETHDesired, to);

        uint256 amountTokenDesired = _calculateAmountForLP(WETH, amountETHDesired, _getPoolPair(token, WETH));

        return addLiquidityETH(token, amountTokenDesired, 0, amountETHDesired, 0, to);
    }

    function addLiquidityETHPercentageToken(address token, uint256 percentageTokenDesired, address to)
        external
        view
        validPercentage(percentageTokenDesired)
        returns (PluginExecution[] memory)
    {
        uint256 amountTokenDesired = _percentageShare(token, percentageTokenDesired, to);
        uint256 amountETHDesired = _calculateAmountForLP(token, amountTokenDesired, _getPoolPair(token, WETH));

        return addLiquidityETH(token, amountTokenDesired, 0, amountETHDesired, 0, to);
    }

    function addLiquidityPercentage(uint256 percentageADesired, address tokenA, address tokenB, address to)
        external
        view
        validPercentage(percentageADesired)
        returns (PluginExecution[] memory)
    {
        uint256 amountADesired = _percentageShare(tokenA, percentageADesired, to);
        uint256 amountBDesired = _calculateAmountForLP(tokenA, amountADesired, _getPoolPair(tokenA, tokenB));

        return addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, 0, 0, to);
    }

    function addLiqudityPercentageOfMaxPossible(address tokenA, address tokenB, uint256 percentage, address to)
        external
        view
        validPercentage(percentage)
        returns (PluginExecution[] memory)
    {
        address pair = _getPoolPair(tokenA, tokenB);

        address _tokenA = tokenA;
        address _tokenB = tokenB;
        if (IUniswapV2Pair(pair).token0() != tokenA) {
            _tokenA = tokenB;
            _tokenB = tokenA;
        }

        (uint256 maxAmountA, uint256 maxAmountB) = _calculateMaxAmounts(_tokenA, _tokenB, pair, to);

        uint256 percentageAmountA = (maxAmountA * percentage) / PERCENTAGE_FACTOR;
        uint256 percentageAmountB = (maxAmountB * percentage) / PERCENTAGE_FACTOR;

        return addLiquidity(_tokenA, _tokenB, percentageAmountA, percentageAmountB, 0, 0, to);
    }

    function removeLiquidityETHPercentage(address token, uint256 liquidityPercentage, address to)
        external
        view
        validPercentage(liquidityPercentage)
        returns (PluginExecution[] memory)
    {
        return removeLiquidityETH(token, _percentageShare(_getPoolPair(token, WETH), liquidityPercentage, to), 0, 0, to);
    }

    function removeLiquidityPercentage(address tokenA, address tokenB, uint256 percentageLiquidity, address to)
        external
        view
        validPercentage(percentageLiquidity)
        returns (PluginExecution[] memory)
    {
        return removeLiquidity(
            tokenA, tokenB, _percentageShare(_getPoolPair(tokenA, tokenB), percentageLiquidity, to), 0, 0, to
        );
    }

    function zap(address tokenA, address tokenB, uint256 amountIn, address to)
        external
        view
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](4);

        address pair = _getPoolPair(tokenA, tokenB);

        uint256 swapAmount = _calculateSwapAmountForProvidingLiquidity(pair, tokenA, amountIn);

        (uint256 amountTokenB, PluginExecution[] memory swapExecutions) = _swap(tokenA, tokenB, swapAmount, to);
        PluginExecution[] memory lpExecutions =
            addLiquidity(tokenA, tokenB, amountIn - swapAmount, amountTokenB, 0, 0, to);

        executions[0] = swapExecutions[0];
        executions[1] = swapExecutions[1];
        executions[2] = lpExecutions[0];
        executions[3] = lpExecutions[1];

        return executions;
    }

    function zapETH(address token, uint256 amountIn, bool inputETH, address to)
        external
        returns (PluginExecution[] memory)
    {
        address pair = _getPoolPair(WETH, token);

        address tokenA = inputETH ? WETH : token;

        uint256 swapAmount = _calculateSwapAmountForProvidingLiquidity(pair, tokenA, amountIn);

        uint256 amountToken;
        uint256 amountETH;
        uint8 executionAmount;
        PluginExecution[] memory swapExecutions;
        if (inputETH) {
            (amountToken, swapExecutions) = _swapETH(token, swapAmount);
            amountETH = amountIn - swapAmount;
            executionAmount = 1;
        } else {
            (amountETH, swapExecutions) = _swapToETH(token, swapAmount);
            amountToken = amountIn - swapAmount;
            executionAmount = 2;
        }

        PluginExecution[] memory executions = new PluginExecution[](executionAmount+2);

        // addLiquidityETH(token, amountToken, 0, amountETH, 0);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Internal Functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _getPoolPair(address tokenA, address tokenB) internal view returns (address) {
        address _poolPair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);

        if (_poolPair == address(0)) {
            revert UniswapV2LPActions__PoolPairDoesNotExist();
        }

        return _poolPair;
    }

    function _calculateAmountForLP(address token, uint256 amount, address poolPair)
        internal
        view
        returns (uint256 amountForLp)
    {
        address token0 = IUniswapV2Pair(poolPair).token0();
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(poolPair).getReserves();

        if (token0 == token) {
            amountForLp = (amount * reserve1) / reserve0;
        } else {
            amountForLp = (amount * reserve0) / reserve1;
        }
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(
            IUniswapV2Router01.addLiquidity,
            (tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline)
        );

        return PluginExecution({target: router, value: 0, data: _data});
    }

    function _addLiquidityETH(
        address token,
        uint256 amountETHDesired,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(
            IUniswapV2Router01.addLiquidityETH, (token, amountTokenDesired, amountTokenMin, amountETHMin, to, deadline)
        );

        return PluginExecution({target: router, value: amountETHDesired, data: _data});
    }

    function _removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(
            IUniswapV2Router01.removeLiquidity, (tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline)
        );

        return PluginExecution({target: router, value: 0, data: _data});
    }

    function _removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(
            IUniswapV2Router01.removeLiquidityETH, (token, liquidity, amountTokenMin, amountETHMin, to, deadline)
        );

        return PluginExecution({target: router, value: 0, data: _data});
    }
}
