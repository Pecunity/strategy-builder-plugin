// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UniswapV2Base} from "./UniswapV2Base.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2SwapActions} from "./interfaces/IUniswapV2SwapActions.sol";

contract UniswapV2SwapActions is UniswapV2Base, IUniswapV2SwapActions {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    constructor(address _router) UniswapV2Base(_router) {
        tokenGetterIDs[IUniswapV2SwapActions.swapPercentageETHForTokens.selector] = 1;
        tokenGetterIDs[IUniswapV2SwapActions.swapExactETHForTokens.selector] = 1;
        tokenGetterIDs[IUniswapV2SwapActions.swapETHForExactTokens.selector] = 1;

        tokenGetterIDs[IUniswapV2SwapActions.swapExactTokensForETH.selector] = 2;
        tokenGetterIDs[IUniswapV2SwapActions.swapTokensForExactETH.selector] = 2;
        tokenGetterIDs[IUniswapV2SwapActions.swapExactTokensForTokens.selector] = 2;
        tokenGetterIDs[IUniswapV2SwapActions.swapTokensForExactTokens.selector] = 2;

        tokenGetterIDs[IUniswapV2SwapActions.swapPercentageTokensForETH.selector] = 3;
        tokenGetterIDs[IUniswapV2SwapActions.swapPercentageTokensForTokens.selector] = 3;
    }

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
        uint256 modAmountInMax;
        if (amountInMax == 0) {
            modAmountInMax = _getMaxAmountIn(path, amountOut);
        } else {
            modAmountInMax = amountInMax;
        }

        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _approveToken(path[0], modAmountInMax);

        executions[1] = _swapTokensForExactTokens(amountOut, modAmountInMax, path, to, _deadline());

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

        return executions;
    }

    function swapTokensForExactETH(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to)
        public
        view
        nonZeroAmount(amountOut)
        returns (PluginExecution[] memory)
    {
        uint256 modAmountInMax;
        if (amountInMax == 0) {
            modAmountInMax = _getMaxAmountIn(path, amountOut);
        } else {
            modAmountInMax = amountInMax;
        }

        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _approveToken(path[0], modAmountInMax);

        executions[1] = _swapTokensForExactETH(amountOut, modAmountInMax, path, to, _deadline());

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

        uint256 modAmountInMax;
        if (amountInMax == 0) {
            modAmountInMax = _getMaxAmountIn(path, amountOut);
        } else {
            modAmountInMax = amountInMax;
        }

        executions[0] = _swapETHForExactTokens(modAmountInMax, amountOut, path, to, _deadline());

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

    function getTokenForSelector(bytes4 selector, bytes memory params) external view override returns (address) {
        uint8 tokenGetterID = tokenGetterIDs[selector];

        if (tokenGetterID == 0 || tokenGetterID > 3) {
            revert InvalidTokenGetterID();
        }

        if (tokenGetterID == 1) {
            return address(0);
        }

        if (tokenGetterID == 2) {
            (,, address[] memory _path,) = abi.decode(params, (uint256, uint256, address[], address));
            return _path[0];
        } else {
            (, address[] memory path,) = abi.decode(params, (uint256, address[], address));
            return path[0];
        }
    }
}
