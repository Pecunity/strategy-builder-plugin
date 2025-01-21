// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPluginExecutor} from "modular-account-libs/interfaces/IPluginExecutor.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";

library UniswapV2RouterExecutionLib {
    function swapExactTokensForTokens(
        address wallet,
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal returns (uint256[] memory) {
        bytes memory _data =
            abi.encodeCall(IUniswapV2Router01.swapExactTokensForTokens, (amountIn, amountOutMin, path, to, deadline));

        bytes memory _res = IPluginExecutor(wallet).executeFromPluginExternal(router, 0, _data);

        return abi.decode(_res, (uint256[]));
    }

    function swapExactTokensForETH(
        address wallet,
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal returns (uint256[] memory) {
        bytes memory _data =
            abi.encodeCall(IUniswapV2Router01.swapExactTokensForETH, (amountIn, amountOutMin, path, to, deadline));

        bytes memory _res = IPluginExecutor(wallet).executeFromPluginExternal(router, 0, _data);

        return abi.decode(_res, (uint256[]));
    }

    function swapTokensForExactTokens(
        address wallet,
        address router,
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal returns (uint256[] memory) {
        bytes memory _data =
            abi.encodeCall(IUniswapV2Router01.swapTokensForExactTokens, (amountOut, amountInMax, path, to, deadline));

        bytes memory _res = IPluginExecutor(wallet).executeFromPluginExternal(router, 0, _data);

        return abi.decode(_res, (uint256[]));
    }

    function swapExactETHForTokens(
        address wallet,
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal returns (uint256[] memory) {
        bytes memory _data =
            abi.encodeCall(IUniswapV2Router01.swapExactETHForTokens, (amountOutMin, path, to, deadline));

        bytes memory _res = IPluginExecutor(wallet).executeFromPluginExternal(router, amountIn, _data);

        return abi.decode(_res, (uint256[]));
    }

    function swapETHForExactTokens(
        address wallet,
        address router,
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal returns (uint256[] memory) {
        bytes memory _data = abi.encodeCall(IUniswapV2Router01.swapETHForExactTokens, (amountOut, path, to, deadline));

        bytes memory _res = IPluginExecutor(wallet).executeFromPluginExternal(router, amountInMax, _data);

        return abi.decode(_res, (uint256[]));
    }

    function swapTokensForExactETH(
        address wallet,
        address router,
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal returns (uint256[] memory) {
        bytes memory _data =
            abi.encodeCall(IUniswapV2Router01.swapTokensForExactETH, (amountOut, amountInMax, path, to, deadline));

        bytes memory _res = IPluginExecutor(wallet).executeFromPluginExternal(router, 0, _data);

        return abi.decode(_res, (uint256[]));
    }

    function addLiquidity(
        address wallet,
        address router,
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) internal returns (uint256, uint256, uint256) {
        bytes memory _data = abi.encodeCall(
            IUniswapV2Router01.addLiquidity,
            (tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline)
        );

        bytes memory _res = IPluginExecutor(wallet).executeFromPluginExternal(router, 0, _data);

        return abi.decode(_res, (uint256, uint256, uint256));
    }

    function addLiquidityETH(
        address wallet,
        address router,
        address token,
        uint256 amountETHDesired,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {}

    function removeLiquidity(
        address wallet,
        address router,
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {}

    function removeLiquidityETH(
        address wallet,
        address router,
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH) {}
}
