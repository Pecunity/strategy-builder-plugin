// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ITokenBurner
 * @notice Interface for the TokenBurner contract.
 *
 * @dev
 * Provides functions for withdrawing fee rewards,
 * swapping reward tokens into PEC, and burning them.
 */
interface ITokenBurner {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃              Errors              ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    error InvalidAmount();
    error InvalidTokenOut(address tokenOut);
    error InvalidPath();
    error NoWithdrawableBalance();

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃              Events              ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    event FeesWithdrawn(address indexed token, uint256 amount);

    event TokenSwappedAndBurned(address indexed tokenIn, uint256 amountIn, uint256 burnedAmount);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃            Functions             ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Withdraws accumulated rewards from FeeHandler.
     *
     * @param token The reward token to withdraw.
     */
    function withdrawFees(address token) external;

    /**
     * @notice Swaps tokenIn into PEC and burns the received PEC.
     *
     * @param tokenIn The token to swap.
     * @param amountIn Amount of tokenIn to swap.
     * @param path PancakeSwap V3 encoded swap path.
     * @param minOut Minimum acceptable PEC output.
     */
    function swapToBurnTokenAndBurn(address tokenIn, uint256 amountIn, bytes calldata path, uint256 minOut) external;
}
