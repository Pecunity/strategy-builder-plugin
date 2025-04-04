// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAction} from "../../../interfaces/IAction.sol";

interface IUniswapV2SwapActions is IAction {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to)
        external
        view
        returns (PluginExecution[] memory);

    function swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to)
        external
        view
        returns (PluginExecution[] memory);

    function swapExactETHForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to)
        external
        view
        returns (PluginExecution[] memory);

    function swapTokensForExactETH(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to)
        external
        view
        returns (PluginExecution[] memory);

    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to)
        external
        view
        returns (PluginExecution[] memory);

    function swapETHForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to)
        external
        view
        returns (PluginExecution[] memory);

    function swapPercentageTokensForTokens(uint256 percentage, address[] calldata path, address to)
        external
        view
        returns (PluginExecution[] memory);

    function swapPercentageTokensForETH(uint256 percentage, address[] calldata path, address to)
        external
        view
        returns (PluginExecution[] memory);

    function swapPercentageETHForTokens(uint256 percentage, address[] calldata path, address to)
        external
        view
        returns (PluginExecution[] memory);
}
