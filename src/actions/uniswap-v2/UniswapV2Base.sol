// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV2Base} from "./interfaces/IUniswapV2Base.sol";

contract UniswapV2Base is IUniswapV2Base {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃     State Variables       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    uint256 public constant DELTA_DEADLINE = 30 seconds;
    uint256 public constant PERCENTAGE_FACTOR = 1000;

    address public immutable router;
    address public immutable factory;
    address public immutable WETH;

    mapping(bytes4 => uint8) public tokenGetterIDs;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Modifier            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    modifier validPercentage(uint256 percentage) {
        if (percentage == 0 || percentage > PERCENTAGE_FACTOR) {
            revert NoValidPercentageAmount();
        }
        _;
    }

    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) {
            revert NoZeroAmountValid();
        }
        _;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    constructor(address _router) {
        router = _router;

        WETH = IUniswapV2Router01(router).WETH();
        factory = IUniswapV2Router01(router).factory();
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Internal functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _percentageShare(address token, uint256 percentage, address account) internal view returns (uint256) {
        uint256 totalTokenAmount = IERC20(token).balanceOf(account);
        return (percentage * totalTokenAmount) / PERCENTAGE_FACTOR;
    }

    function _percentageShareETH(uint256 percentage, address account) internal view returns (uint256) {
        uint256 totalBalanceETH = account.balance;
        return (totalBalanceETH * percentage) / PERCENTAGE_FACTOR;
    }

    function _approveToken(address token, uint256 amount) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(IERC20.approve, (address(router), amount));

        return PluginExecution({target: token, value: 0, data: _data});
    }

    function _getMaxAmountIn(address[] memory path, uint256 amountOut) internal view returns (uint256) {
        return IUniswapV2Router01(router).getAmountsIn(amountOut, path)[0];
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + DELTA_DEADLINE;
    }

    function _swap(address tokenIn, address tokenOut, uint256 amountIn, address to)
        internal
        view
        returns (uint256, PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _approveToken(tokenIn, amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amountsOut = IUniswapV2Router01(router).getAmountsOut(amountIn, path);
        executions[1] = _swapExactTokensForTokens(amountIn, 0, path, to, _deadline());

        return (amountsOut[1], executions);
    }

    function _swapETH(address token, uint256 amountIn, address to)
        internal
        view
        returns (uint256, PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](1);

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = token;

        uint256[] memory amountsOut = IUniswapV2Router01(router).getAmountsOut(amountIn, path);
        executions[0] = _swapExactETHForTokens(amountIn, 0, path, to, _deadline());

        return (amountsOut[1], executions);
    }

    function _swapToETH(address token, uint256 amountIn, address to)
        internal
        view
        returns (uint256, PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _approveToken(token, amountIn);

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = WETH;

        uint256[] memory amountsOut = IUniswapV2Router01(router).getAmountsOut(amountIn, path);
        executions[1] = _swapExactTokensForETH(amountIn, 0, path, to, _deadline());

        return (amountsOut[1], executions);
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

    function _swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal view returns (PluginExecution memory) {
        bytes memory _data =
            abi.encodeCall(IUniswapV2Router01.swapExactTokensForETH, (amountIn, amountOutMin, path, to, deadline));

        return PluginExecution({target: router, value: 0, data: _data});
    }

    function _swapExactETHForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal view returns (PluginExecution memory) {
        bytes memory _data =
            abi.encodeCall(IUniswapV2Router01.swapExactETHForTokens, (amountOutMin, path, to, deadline));

        return PluginExecution({target: router, value: amountIn, data: _data});
    }

    function _calculateSwapAmountForProvidingLiquidity(address pair, address tokenA, uint256 amountIn)
        internal
        view
        returns (uint256)
    {
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pair).getReserves();

        if (IUniswapV2Pair(pair).token0() == tokenA) {
            return _getSwapAmount(reserve0, amountIn);
        } else {
            return _getSwapAmount(reserve1, amountIn);
        }
    }

    function uniswapV2RouterAddress() external view returns (address) {
        return address(router);
    }

    function getTokenForSelector(bytes4, bytes memory) external view virtual returns (address) {
        return address(0);
    }

    /*
    s = optimal swap amount
    r = amount of reserve for token a
    a = amount of token a the user currently has (not added to reserve yet)
    f = swap fee percent
    s = (sqrt(((2 - f)r)^2 + 4(1 - f)ar) - (2 - f)r) / (2(1 - f))
    */
    function _getSwapAmount(uint256 r, uint256 a) public pure returns (uint256) {
        return (sqrt(r * (r * 3988009 + a * 3988000)) - r * 1997) / 1994;
    }

    function sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
