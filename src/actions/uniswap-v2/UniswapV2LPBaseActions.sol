// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UniswapV2Base} from "./UniswapV2Base.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error UniswapVLPBaseActions__PoolPairDoesNotExist();
error UniswapV2LPBaseActions__NotZeroAmountForBothTokensAllowed();

contract UniswapV2LPBaseActions is UniswapV2Base {
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
            revert UniswapV2LPBaseActions__NotZeroAmountForBothTokensAllowed();
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
            revert UniswapV2LPBaseActions__NotZeroAmountForBothTokensAllowed();
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

        // (uint256 amountA, uint256 amountB) = msg.sender.removeLiquidity(
        //     address(router), tokenA, tokenB, liquidity, amountAMin, amountBMin, msg.sender, _deadline()
        // );

        return executions;
    }

    // function removeLiquidityETH(address token, uint256 liquidity, uint256 amountTokenMin, uint256 amountETHMin)
    //     public
    //     nonZeroAmount(liquidity)
    // {
    //     // _approveToken(_getPoolPair(token, router.WETH()), liquidity);

    //     // (uint256 amountToken, uint256 amountETH) = msg.sender.removeLiquidityETH(
    //     //     address(router), token, liquidity, amountTokenMin, amountETHMin, msg.sender, _deadline()
    //     // );

    //     // emit LiquidiyRemoved(token, address(0), amountToken, amountETH, liquidity);
    // }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Internal Functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _getPoolPair(address tokenA, address tokenB) internal view returns (address) {
        address _poolPair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);

        if (_poolPair == address(0)) {
            revert UniswapVLPBaseActions__PoolPairDoesNotExist();
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
}
