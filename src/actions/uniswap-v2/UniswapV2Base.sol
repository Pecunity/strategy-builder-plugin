// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPluginExecutor} from "modular-account-libs/interfaces/IPluginExecutor.sol";
import {UniswapV2RouterExecutionLib} from "./lib/UniswapV2RouterExecutionLib.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error UniswapV2Base__FailedToApproveTokens();
error UniswapV2Base__PoolPairDoesNotExist();
error UniswapV2Base__NotZeroAmountForBothTokensAllowed();
error UniswapV2Base__NoValidPercentageAmount();
error UniswapV2Base__NoZeroAmountValid();

contract UniswapV2Base {
    using UniswapV2RouterExecutionLib for address;

    uint256 constant DELTA_DEADLINE = 30 seconds;
    uint256 constant PERCENTAGE_FACTOR = 1000;

    IUniswapV2Router01 public immutable router;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃         Events            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    event TokenSwap(address[] path, uint256[] amountsOut);
    event LiquidityAdded(address tokenA, address tokenB, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidiyRemoved(address tokenA, address tokenB, uint256 amountA, uint256 amountB, uint256 liquidity);

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
        router = IUniswapV2Router01(_router);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /* ====== Base Swap Functions ====== */

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path)
        public
        nonZeroAmount(amountIn)
    {
        _approveToken(path[0], amountIn);

        uint256[] memory amountsOut =
            msg.sender.swapExactTokensForTokens(address(router), amountIn, amountOutMin, path, msg.sender, _deadline());
        // router.swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), _deadline());

        emit TokenSwap(path, amountsOut);
    }

    function swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path)
        external
        nonZeroAmount(amountOut)
    {
        _approveToken(path[0], amountInMax);

        uint256[] memory amountsOut =
            msg.sender.swapTokensForExactTokens(address(router), amountOut, amountInMax, path, msg.sender, _deadline());

        uint256 allowance = IERC20(path[0]).allowance(msg.sender, address(router));

        if (allowance > 0) {
            _approveToken(path[0], 0);
        }

        emit TokenSwap(path, amountsOut);
    }

    function swapExactETHForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path)
        public
        nonZeroAmount(amountIn)
    {
        uint256[] memory amountsOut =
            msg.sender.swapExactETHForTokens(address(router), amountIn, amountOutMin, path, msg.sender, _deadline());

        emit TokenSwap(path, amountsOut);
    }

    function swapTokensForExactETH(uint256 amountOut, uint256 amountInMax, address[] calldata path)
        external
        nonZeroAmount(amountOut)
    {
        _approveToken(path[0], amountInMax);

        uint256[] memory amountsOut =
            msg.sender.swapTokensForExactETH(address(router), amountOut, amountInMax, path, msg.sender, _deadline());

        uint256 allowance = IERC20(path[0]).allowance(msg.sender, address(router));

        if (allowance > 0) {
            _approveToken(path[0], 0);
        }

        emit TokenSwap(path, amountsOut);
    }

    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path)
        public
        nonZeroAmount(amountIn)
    {
        _approveToken(path[0], amountIn);

        uint256[] memory amountsOut =
            msg.sender.swapExactTokensForETH(address(router), amountIn, amountOutMin, path, msg.sender, _deadline());

        emit TokenSwap(path, amountsOut);
    }

    function swapETHForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path)
        external
        nonZeroAmount(amountOut)
    {
        if (amountInMax == 0) {
            amountInMax = _getMaxAmountIn(path, amountOut);
        }

        uint256[] memory amountsOut =
            msg.sender.swapETHForExactTokens(address(router), amountInMax, amountOut, path, msg.sender, _deadline());

        emit TokenSwap(path, amountsOut);
    }

    /* ====== Base LP Functions ====== */

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) public {
        if (amountADesired == 0 && amountBDesired == 0) {
            revert UniswapV2Base__NotZeroAmountForBothTokensAllowed();
        }

        if (amountADesired == 0) {
            amountADesired = _calculateAmountForLP(tokenB, amountBDesired, _getPoolPair(tokenA, tokenB));
        }

        if (amountBDesired == 0) {
            amountBDesired = _calculateAmountForLP(tokenA, amountADesired, _getPoolPair(tokenA, tokenB));
        }

        _approveToken(tokenA, amountADesired);
        _approveToken(tokenB, amountBDesired);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = msg.sender.addLiquidity(
            address(router),
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            msg.sender,
            _deadline()
        );

        emit LiquidityAdded(tokenA, tokenB, amountA, amountB, liquidity);
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHDesired,
        uint256 amountETHMin
    ) public {
        if (amountTokenDesired == 0 && amountETHDesired == 0) {
            revert UniswapV2Base__NotZeroAmountForBothTokensAllowed();
        }

        if (amountTokenDesired == 0) {
            amountTokenDesired =
                _calculateAmountForLP(router.WETH(), amountETHDesired, _getPoolPair(token, router.WETH()));
        }

        if (amountETHDesired == 0) {
            amountETHDesired = _calculateAmountForLP(token, amountTokenDesired, _getPoolPair(token, router.WETH()));
        }

        _approveToken(token, amountTokenDesired);

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = msg.sender.addLiquidityETH(
            address(router),
            token,
            amountETHDesired,
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            msg.sender,
            _deadline()
        );

        emit LiquidityAdded(address(0), token, amountETH, amountToken, liquidity);
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 liquidity, uint256 amountAMin, uint256 amountBMin)
        public
        nonZeroAmount(liquidity)
    {
        _approveToken(_getPoolPair(tokenA, tokenB), liquidity);

        (uint256 amountA, uint256 amountB) = msg.sender.removeLiquidity(
            address(router), tokenA, tokenB, liquidity, amountAMin, amountBMin, msg.sender, _deadline()
        );

        emit LiquidiyRemoved(tokenA, tokenB, amountA, amountB, liquidity);
    }

    function removeLiquidityETH(address token, uint256 liquidity, uint256 amountTokenMin, uint256 amountETHMin)
        public
        nonZeroAmount(liquidity)
    {
        _approveToken(_getPoolPair(token, router.WETH()), liquidity);

        (uint256 amountToken, uint256 amountETH) = msg.sender.removeLiquidityETH(
            address(router), token, liquidity, amountTokenMin, amountETHMin, msg.sender, _deadline()
        );

        emit LiquidiyRemoved(token, address(0), amountToken, amountETH, liquidity);
    }

    /* ====== Percentage Swap Functions ====== */

    function swapPercentageTokensForTokens(uint256 percentage, address[] calldata path)
        external
        validPercentage(percentage)
    {
        swapExactTokensForTokens(_percentageShare(path[0], percentage), 0, path);
    }

    function swapPercentageTokensForETH(uint256 percentage, address[] calldata path)
        external
        validPercentage(percentage)
    {
        swapExactTokensForETH(_percentageShare(path[0], percentage), 0, path);
    }

    function swapPercentageETHForTokens(uint256 percentage, address[] calldata path)
        external
        validPercentage(percentage)
    {
        swapExactETHForTokens(_percentageShareETH(percentage), 0, path);
    }

    /* ====== Percentage LP Functions ====== */

    function addLiquidityETHPercentage(address token, uint256 percentageETHDesired)
        public
        validPercentage(percentageETHDesired)
    {
        uint256 amountETHDesired = _percentageShareETH(percentageETHDesired);
        // // uint256 amountETHDesired = 1;
        // address _poolPair = _getPoolPair(token, router.WETH());
        // address _WETH = router.WETH();
        uint256 amountTokenDesired =
            _calculateAmountForLP(router.WETH(), amountETHDesired, _getPoolPair(token, router.WETH()));
        // uint256 amountTokenDesired = _calculateAmountForLP(_WETH, amountETHDesired, _poolPair);
        addLiquidityETH(token, amountTokenDesired, 0, amountETHDesired, 0);
    }

    function addLiquidityETHPercentageToken(address token, uint256 percentageTokenDesired)
        external
        validPercentage(percentageTokenDesired)
    {
        uint256 amountTokenDesired = _percentageShare(token, percentageTokenDesired);
        uint256 amountETHDesired = _calculateAmountForLP(token, amountTokenDesired, _getPoolPair(token, router.WETH()));

        addLiquidityETH(token, amountTokenDesired, 0, amountETHDesired, 0);
    }

    function addLiquidityPercentage(uint256 percentageADesired, address tokenA, address tokenB)
        external
        validPercentage(percentageADesired)
    {
        uint256 amountADesired = _percentageShare(tokenA, percentageADesired);
        uint256 amountBDesired = _calculateAmountForLP(tokenA, amountADesired, _getPoolPair(tokenA, tokenB));

        _approveToken(tokenA, amountADesired);
        _approveToken(tokenB, amountBDesired);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = msg.sender.addLiquidity(
            address(router), tokenA, tokenB, amountADesired, amountBDesired, 0, 0, msg.sender, _deadline()
        );

        emit LiquidityAdded(tokenA, tokenB, amountA, amountB, liquidity);
    }

    function addLiqudityPercentageOfMaxPossible(address tokenA, address tokenB, uint256 percentage)
        external
        validPercentage(percentage)
    {
        address pair = _getPoolPair(tokenA, tokenB);

        address _tokenA = tokenA;
        address _tokenB = tokenB;
        if (IUniswapV2Pair(pair).token0() != tokenA) {
            _tokenA = tokenB;
            _tokenB = tokenA;
        }

        (uint256 maxAmountA, uint256 maxAmountB) = _calculateMaxAmounts(_tokenA, _tokenB, pair);

        uint256 percentageAmountA = (maxAmountA * percentage) / PERCENTAGE_FACTOR;
        uint256 percentageAmountB = (maxAmountB * percentage) / PERCENTAGE_FACTOR;

        addLiquidity(_tokenA, _tokenB, percentageAmountA, percentageAmountB, 0, 0);
    }

    function removeLiquidityETHPercentage(address token, uint256 liquidityPercentage)
        external
        validPercentage(liquidityPercentage)
    {
        removeLiquidityETH(token, _percentageShare(_getPoolPair(token, router.WETH()), liquidityPercentage), 0, 0);
    }

    function removeLiquidityPercentage(address tokenA, address tokenB, uint256 percentageLiquidity)
        external
        validPercentage(percentageLiquidity)
    {
        removeLiquidity(tokenA, tokenB, _percentageShare(_getPoolPair(tokenA, tokenB), percentageLiquidity), 0, 0);
    }

    function zap(address tokenA, address tokenB, uint256 amountIn) external {
        address pair = _getPoolPair(tokenA, tokenB);

        uint256 swapAmount = _calculateSwapAmountForProvidingLiquidity(pair, tokenA, amountIn);

        uint256 amountTokenB = _swap(tokenA, tokenB, swapAmount);
        addLiquidity(tokenA, tokenB, amountIn - swapAmount, amountTokenB, 0, 0);
    }

    function zapETH(address token, uint256 amountIn, bool inputETH) external {
        address WETH = router.WETH();
        address pair = _getPoolPair(WETH, token);

        address tokenA = inputETH ? WETH : token;

        uint256 swapAmount = _calculateSwapAmountForProvidingLiquidity(pair, tokenA, amountIn);

        uint256 amountToken;
        uint256 amountETH;
        if (inputETH) {
            amountToken = _swapETH(token, swapAmount);
            amountETH = amountIn - swapAmount;
        } else {
            amountETH = _swapToETH(token, swapAmount);
            amountToken = amountIn - swapAmount;
        }

        addLiquidityETH(token, amountToken, 0, amountETH, 0);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Internal functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _calculateMaxAmounts(address tokenA, address tokenB, address pair)
        internal
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

    function _percentageShare(address token, uint256 percentage) internal view returns (uint256) {
        uint256 totalTokenAmount = IERC20(token).balanceOf(msg.sender);
        return (percentage * totalTokenAmount) / PERCENTAGE_FACTOR;
    }

    function _percentageShareETH(uint256 percentage) internal view returns (uint256) {
        uint256 totalBalanceETH = msg.sender.balance;
        return (totalBalanceETH * percentage) / PERCENTAGE_FACTOR;
    }

    function _approveToken(address token, uint256 amount) internal {
        bytes memory _data = abi.encodeCall(IERC20.approve, (address(router), amount));
        bytes memory _res = IPluginExecutor(msg.sender).executeFromPluginExternal(token, 0, _data);
        bool success = abi.decode(_res, (bool));

        if (!success) {
            revert UniswapV2Base__FailedToApproveTokens();
        }
    }

    function _getPoolPair(address tokenA, address tokenB) internal view returns (address) {
        address _factory = router.factory();
        address _poolPair = IUniswapV2Factory(_factory).getPair(tokenA, tokenB);

        if (_poolPair == address(0)) {
            revert UniswapV2Base__PoolPairDoesNotExist();
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

    function _getMaxAmountIn(address[] memory path, uint256 amountOut) internal view returns (uint256) {
        return router.getAmountsIn(amountOut, path)[0];
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + DELTA_DEADLINE;
    }

    function _swap(address tokenIn, address tokenOut, uint256 amountIn) internal returns (uint256) {
        _approveToken(tokenIn, amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amountsOut =
            msg.sender.swapExactTokensForTokens(address(router), amountIn, 0, path, msg.sender, _deadline());

        emit TokenSwap(path, amountsOut);

        return amountsOut[1];
    }

    function _swapETH(address token, uint256 amountIn) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = token;

        uint256[] memory amountsOut =
            msg.sender.swapExactETHForTokens(address(router), amountIn, 0, path, msg.sender, _deadline());
        emit TokenSwap(path, amountsOut);

        return amountsOut[1];
    }

    function _swapToETH(address token, uint256 amountIn) internal returns (uint256) {
        _approveToken(token, amountIn);

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = router.WETH();

        uint256[] memory amountsOut =
            msg.sender.swapExactTokensForETH(address(router), amountIn, 0, path, msg.sender, _deadline());

        emit TokenSwap(path, amountsOut);

        return amountsOut[1];
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
