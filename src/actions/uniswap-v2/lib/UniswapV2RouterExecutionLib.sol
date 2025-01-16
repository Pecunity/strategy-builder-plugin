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
        address[] calldata path,
        address to,
        uint256 deadline
    ) internal returns (uint256[] memory amounts) {
        bytes memory _data =
            abi.encodeCall(IUniswapV2Router01.swapExactTokensForTokens, (amountIn, amountOutMin, path, to, deadline));

        bytes memory _res = IPluginExecutor(wallet).executeFromPluginExternal(router, 0, _data);

        return abi.decode(_res, (uint256[]));
    }
}
