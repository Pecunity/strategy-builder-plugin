// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UniswapV2Base} from "./UniswapV2Base.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2LPActions} from "./interfaces/IUniswapV2LPActions.sol";

contract UniswapV2LPActions is UniswapV2Base, IUniswapV2LPActions {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    constructor(address _router) UniswapV2Base(_router) {
        tokenGetterIDs[IUniswapV2LPActions.addLiquidityETH.selector] = 1;
        tokenGetterIDs[IUniswapV2LPActions.addLiqudityPercentageETH.selector] = 1;
        tokenGetterIDs[IUniswapV2LPActions.removeLiquidityETH.selector] = 1;
        tokenGetterIDs[IUniswapV2LPActions.removeLiquidityETHPercentage.selector] = 1;
        tokenGetterIDs[IUniswapV2LPActions.zapETH.selector] = 1;

        tokenGetterIDs[IUniswapV2LPActions.addLiquidity.selector] = 2;

        tokenGetterIDs[IUniswapV2LPActions.removeLiquidity.selector] = 3;

        tokenGetterIDs[IUniswapV2LPActions.zap.selector] = 4;
        tokenGetterIDs[IUniswapV2LPActions.removeLiquidityPercentage.selector] = 4;
        tokenGetterIDs[IUniswapV2LPActions.addLiqudityPercentage.selector] = 4;
    }

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
            revert NotZeroAmountForBothTokensAllowed();
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
            revert NotZeroAmountForBothTokensAllowed();
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

    function addLiqudityPercentage(address tokenA, address tokenB, uint256 percentage, address wallet)
        external
        view
        validPercentage(percentage)
        returns (PluginExecution[] memory)
    {
        address pair = _getPoolPair(tokenA, tokenB);

        (uint256 maxAmountA, uint256 maxAmountB) = _getMaxAmounts(tokenA, tokenB, pair, wallet);

        return addLiquidity(
            tokenA,
            tokenB,
            (maxAmountA * percentage) / PERCENTAGE_FACTOR,
            (maxAmountB * percentage) / PERCENTAGE_FACTOR,
            0,
            0,
            wallet
        );
    }

    function addLiqudityPercentageETH(address token, uint256 percentage, address wallet)
        external
        view
        validPercentage(percentage)
        returns (PluginExecution[] memory)
    {
        address pair = _getPoolPair(token, WETH);

        (uint256 maxAmountToken, uint256 maxAmountETH) = _getMaxAmountsETH(token, pair, wallet);

        return addLiquidityETH(
            token,
            maxAmountToken * percentage / PERCENTAGE_FACTOR,
            0,
            maxAmountETH * percentage / PERCENTAGE_FACTOR,
            0,
            wallet
        );
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
        PluginExecution[] memory executions = new PluginExecution[](5);

        address pair = _getPoolPair(tokenA, tokenB);

        uint256 swapAmount = _calculateSwapAmountForProvidingLiquidity(pair, tokenA, amountIn);

        (uint256 amountTokenB, PluginExecution[] memory swapExecutions) = _swap(tokenA, tokenB, swapAmount, to);
        PluginExecution[] memory lpExecutions =
            addLiquidity(tokenA, tokenB, amountIn - swapAmount, amountTokenB, 0, 0, to);

        executions[0] = swapExecutions[0];
        executions[1] = swapExecutions[1];
        executions[2] = lpExecutions[0];
        executions[3] = lpExecutions[1];
        executions[4] = lpExecutions[2];

        return executions;
    }

    function zapETH(address token, uint256 amountIn, bool inputETH, address to)
        external
        view
        returns (PluginExecution[] memory)
    {
        (uint256 amountToken, uint256 amountETH, PluginExecution[] memory swapExecutions) =
            _swapToETHorETH(token, amountIn, inputETH, to);

        PluginExecution[] memory executions = new PluginExecution[](swapExecutions.length + 2);

        PluginExecution[] memory lpExecutions = addLiquidityETH(token, amountToken, 0, amountETH, 0, to);

        executions[0] = swapExecutions[0];

        if (swapExecutions.length == 1) {
            executions[1] = lpExecutions[0];
            executions[2] = lpExecutions[1];
        } else {
            executions[1] = swapExecutions[1];
            executions[2] = lpExecutions[0];
            executions[3] = lpExecutions[1];
        }

        return executions;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Internal Functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _getPoolPair(address tokenA, address tokenB) internal view returns (address) {
        address _poolPair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);

        if (_poolPair == address(0)) {
            revert PoolPairDoesNotExist();
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

    function _getMaxAmounts(address tokenA, address tokenB, address pair, address account)
        internal
        view
        returns (uint256 maxAmountA, uint256 maxAmountB)
    {
        (uint112 _reserveA, uint112 _reserveB,) = IUniswapV2Pair(pair).getReserves();

        uint112 reserveA;
        uint112 reserveB;
        if (IUniswapV2Pair(pair).token0() == tokenA) {
            reserveA = _reserveA;
            reserveB = _reserveB;
        } else {
            reserveA = _reserveB;
            reserveB = _reserveA;
        }

        uint256 balanceA = IERC20(tokenA).balanceOf(account);
        uint256 balanceB = IERC20(tokenB).balanceOf(account);

        (maxAmountA, maxAmountB) = _calculateMaxAmounts(reserveA, reserveB, balanceA, balanceB);
    }

    function _getMaxAmountsETH(address token, address pair, address account)
        internal
        view
        returns (uint256 maxAmountToken, uint256 maxAmountETH)
    {
        (uint112 reserveA, uint112 reserveB,) = IUniswapV2Pair(pair).getReserves();

        uint112 reserveToken;
        uint112 reserveETH;
        if (IUniswapV2Pair(pair).token0() == token) {
            reserveToken = reserveA;
            reserveETH = reserveB;
        } else {
            reserveToken = reserveB;
            reserveETH = reserveA;
        }

        uint256 balanceToken = IERC20(token).balanceOf(account);
        uint256 balanceETH = account.balance;

        (maxAmountToken, maxAmountETH) = _calculateMaxAmounts(reserveToken, reserveETH, balanceToken, balanceETH);
    }

    function _calculateMaxAmounts(uint112 reserveA, uint112 reserveB, uint256 balanceA, uint256 balanceB)
        internal
        view
        returns (uint256 maxAmountA, uint256 maxAmountB)
    {
        maxAmountA = balanceA;
        maxAmountB = balanceB;

        uint256 requiredB = (balanceA * reserveB) / reserveA;

        if (requiredB > balanceB) {
            maxAmountA = (balanceB * reserveA) / reserveB;
        } else {
            maxAmountB = requiredB;
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

    function _swapToETHorETH(address token, uint256 amountIn, bool inputETH, address to)
        internal
        view
        returns (uint256 amountToken, uint256 amountETH, PluginExecution[] memory swapExecutions)
    {
        address pair = _getPoolPair(WETH, token);

        address tokenA = inputETH ? WETH : token;

        uint256 swapAmount = _calculateSwapAmountForProvidingLiquidity(pair, tokenA, amountIn);

        if (inputETH) {
            (amountToken, swapExecutions) = _swapETH(token, swapAmount, to);
            amountETH = amountIn - swapAmount;
        } else {
            (amountETH, swapExecutions) = _swapToETH(token, swapAmount, to);
            amountToken = amountIn - swapAmount;
        }
    }

    function getTokenForSelector(bytes4 selector, bytes memory params) external view override returns (address) {
        uint8 tokenGetterID = tokenGetterIDs[selector];

        if (tokenGetterID == 0 || tokenGetterID > 4) {
            revert InvalidTokenGetterID();
        }

        if (tokenGetterID == 1) {
            return address(0);
        }

        if (tokenGetterID == 2) {
            (address token,,,,,,) = abi.decode(params, (address, address, uint256, uint256, uint256, uint256, address));
            return token;
        }

        if (tokenGetterID == 3) {
            (address token,,,,,) = abi.decode(params, (address, address, uint256, uint256, uint256, address));
            return token;
        } else {
            (address token,,,) = abi.decode(params, (address, address, uint256, address));
            return token;
        }
    }
}
