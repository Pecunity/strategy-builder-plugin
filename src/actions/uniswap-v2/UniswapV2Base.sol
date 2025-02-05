// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAction} from "../../interfaces/IAction.sol";

error UniswapV2Base__FailedToApproveTokens();
error UniswapV2Base__PoolPairDoesNotExist();
error UniswapV2Base__NotZeroAmountForBothTokensAllowed();
error UniswapV2Base__NoValidPercentageAmount();
error UniswapV2Base__NoZeroAmountValid();

contract UniswapV2Base is IAction {
    uint256 constant DELTA_DEADLINE = 30 seconds;
    uint256 constant PERCENTAGE_FACTOR = 1000;

    address public immutable router;
    address public immutable factory;
    address public immutable WETH;

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

        WETH = IUniswapV2Router01(router).WETH();
        factory = IUniswapV2Router01(router).factory();
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Internal functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _calculateMaxAmounts(address tokenA, address tokenB, address pair)
        internal
        view
        returns (uint256 maxAmountA, uint256 maxAmountB)
    {
        (uint112 reserveA, uint112 reserveB,) = IUniswapV2Pair(pair).getReserves();

        uint256 balanceTokenA = IERC20(tokenA).balanceOf(msg.sender);
        uint256 balanceTokenB = IERC20(tokenB).balanceOf(msg.sender);

        maxAmountA = balanceTokenA;
        maxAmountB = balanceTokenB;

        uint256 requiredB = (balanceTokenA * reserveB) / reserveA;

        if (requiredB > balanceTokenB) {
            maxAmountA = (balanceTokenB * reserveA) / reserveB;
        } else {
            maxAmountB = requiredB;
        }
    }

    // function _percentageShare(address token, uint256 percentage) internal view returns (uint256) {
    //     uint256 totalTokenAmount = IERC20(token).balanceOf(msg.sender);
    //     return (percentage * totalTokenAmount) / PERCENTAGE_FACTOR;
    // }

    // function _percentageShareETH(uint256 percentage) internal view returns (uint256) {
    //     uint256 totalBalanceETH = msg.sender.balance;
    //     return (totalBalanceETH * percentage) / PERCENTAGE_FACTOR;
    // }

    // function _approveToken(address token, uint256 amount) internal {
    //     bytes memory _data = abi.encodeCall(IERC20.approve, (address(router), amount));
    //     bytes memory _res = IPluginExecutor(msg.sender).executeFromPluginExternal(token, 0, _data);
    //     bool success = abi.decode(_res, (bool));

    //     if (!success) {
    //         revert UniswapV2Base__FailedToApproveTokens();
    //     }
    // }

    // function _getPoolPair(address tokenA, address tokenB) internal view returns (address) {
    //     address _factory = IUniswapV2Router01(router).factory();
    //     address _poolPair = IUniswapV2Factory(_factory).getPair(tokenA, tokenB);

    //     if (_poolPair == address(0)) {
    //         revert UniswapV2Base__PoolPairDoesNotExist();
    //     }

    //     return _poolPair;
    // }

    function _approveToken(address token, uint256 amount) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(IERC20.approve, (address(router), amount));

        return PluginExecution({target: token, value: 0, data: _data});
    }

    // function _calculateAmountForLP(address token, uint256 amount, address poolPair)
    //     internal
    //     view
    //     returns (uint256 amountForLp)
    // {
    //     address token0 = IUniswapV2Pair(poolPair).token0();
    //     (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(poolPair).getReserves();

    //     if (token0 == token) {
    //         amountForLp = (amount * reserve1) / reserve0;
    //     } else {
    //         amountForLp = (amount * reserve0) / reserve1;
    //     }
    // }

    function _getMaxAmountIn(address[] memory path, uint256 amountOut) internal view returns (uint256) {
        return IUniswapV2Router01(router).getAmountsIn(amountOut, path)[0];
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + DELTA_DEADLINE;
    }

    // function _swap(address tokenIn, address tokenOut, uint256 amountIn) internal returns (uint256) {
    //     _approveToken(tokenIn, amountIn);

    //     address[] memory path = new address[](2);
    //     path[0] = tokenIn;
    //     path[1] = tokenOut;

    //     uint256[] memory amountsOut =
    //         msg.sender.swapExactTokensForTokens(address(router), amountIn, 0, path, msg.sender, _deadline());

    //     emit TokenSwap(path, amountsOut);

    //     return amountsOut[1];
    // }

    // function _swapETH(address token, uint256 amountIn) internal returns (uint256) {
    //     address[] memory path = new address[](2);
    //     path[0] = router.WETH();
    //     path[1] = token;

    //     uint256[] memory amountsOut =
    //         msg.sender.swapExactETHForTokens(address(router), amountIn, 0, path, msg.sender, _deadline());
    //     emit TokenSwap(path, amountsOut);

    //     return amountsOut[1];
    // }

    // function _swapToETH(address token, uint256 amountIn) internal returns (uint256) {
    //     _approveToken(token, amountIn);

    //     address[] memory path = new address[](2);
    //     path[0] = token;
    //     path[1] = router.WETH();

    //     uint256[] memory amountsOut =
    //         msg.sender.swapExactTokensForETH(address(router), amountIn, 0, path, msg.sender, _deadline());

    //     emit TokenSwap(path, amountsOut);

    //     return amountsOut[1];
    // }

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
