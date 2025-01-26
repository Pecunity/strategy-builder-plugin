// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error UniswapV2Base__FailedToApproveTokens();
error UniswapV2Base__PoolPairDoesNotExist();
error UniswapV2Base__NotZeroAmountForBothTokensAllowed();
error UniswapV2Base__NoValidPercentageAmount();
error UniswapV2Base__NoZeroAmountValid();

contract UniswapV2Actions {
    struct PluginExecution {
        address target;
        uint256 value;
        bytes data;
    }

    uint256 constant DELTA_DEADLINE = 30 seconds;
    uint256 constant PERCENTAGE_FACTOR = 1000;

    address public immutable router;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Modifier            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    modifier validPercentage(uint256 percentage) {
        if (percentage == 0 || percentage > PERCENTAGE_FACTOR) {
            revert UniswapV2Base__NoValidPercentageAmount();
        }
        _;
    }

    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) {
            revert UniswapV2Base__NoZeroAmountValid();
        }
        _;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    constructor(address _router) {
        router = _router;
    }

    /* ====== Base Swap Functions ====== */

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path)
        public
        view
        nonZeroAmount(amountIn)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);
        executions[0] = _approveToken(path[0], amountIn);

        executions[1] = _swapExactTokensForTokens(amountIn, amountOutMin, path, msg.sender, _deadline());
        return executions;
    }

    function _approveToken(address token, uint256 amount) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(IERC20.approve, (address(router), amount));

        return PluginExecution({target: token, value: 0, data: _data});
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + DELTA_DEADLINE;
    }

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
}
