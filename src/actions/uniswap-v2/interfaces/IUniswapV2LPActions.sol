// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAction} from "../../../interfaces/IAction.sol";

interface IUniswapV2LPActions is IAction {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external view returns (PluginExecution[] memory);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHDesired,
        uint256 amountETHMin,
        address to
    ) external view returns (PluginExecution[] memory);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external view returns (PluginExecution[] memory);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to
    ) external view returns (PluginExecution[] memory);

    function addLiqudityPercentage(address tokenA, address tokenB, uint256 percentage, address wallet)
        external
        view
        returns (PluginExecution[] memory);

    function addLiqudityPercentageETH(address token, uint256 percentage, address wallet)
        external
        view
        returns (PluginExecution[] memory);

    function removeLiquidityETHPercentage(address token, uint256 liquidityPercentage, address to)
        external
        view
        returns (PluginExecution[] memory);

    function removeLiquidityPercentage(address tokenA, address tokenB, uint256 percentageLiquidity, address to)
        external
        view
        returns (PluginExecution[] memory);

    function zap(address tokenA, address tokenB, uint256 amountIn, address to)
        external
        view
        returns (PluginExecution[] memory);

    function zapETH(address token, uint256 amountIn, bool inputETH, address to)
        external
        view
        returns (PluginExecution[] memory);
}
