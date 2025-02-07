// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UniswapV2Base} from "./UniswapV2Base.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapV2SwapActions is UniswapV2Base {
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

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃  Percentage Swap PluginExecution Functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function swapPercentageTokensForTokens(uint256 percentage, address[] calldata path, address to)
        external
        view
        validPercentage(percentage)
        returns (PluginExecution[] memory)
    {
        return swapExactTokensForTokens(_percentageShare(path[0], percentage, to), 0, path, to);
    }

    function swapPercentageTokensForETH(uint256 percentage, address[] calldata path, address to)
        external
        view
        validPercentage(percentage)
        returns (PluginExecution[] memory)
    {
        return swapExactTokensForETH(_percentageShare(path[0], percentage, to), 0, path, to);
    }

    function swapPercentageETHForTokens(uint256 percentage, address[] calldata path, address to)
        external
        view
        validPercentage(percentage)
        returns (PluginExecution[] memory)
    {
        return swapExactETHForTokens(_percentageShareETH(percentage, to), 0, path, to);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Internal Functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

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
