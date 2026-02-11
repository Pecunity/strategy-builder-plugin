// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IFeeHandler} from "../interfaces/IFeeHandler.sol";
import {IERC20Burnable} from "../interfaces/IERC20Burnable.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {ITokenBurner} from "../interfaces/ITokenBurner.sol";

/**
 * ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
 * ┃                         TOKEN BURNER                          ┃
 * ┃                                                               ┃
 * ┃  Withdraws fee rewards, swaps them into PEC and burns tokens. ┃
 * ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
 *
 * @title TokenBurner
 * @author 3Blocks
 *
 * @notice
 * This contract is responsible for:
 * - Withdrawing accumulated fee rewards from a FeeHandler
 * - Swapping reward tokens into the primary burnToken (PEC)
 * - Burning the received PEC permanently
 *
 * @dev
 * Uses PancakeSwap V3 (Uniswap V3 compatible router).
 * The swap path MUST always end in the burnToken address.
 */
contract TokenBurner is Ownable, ITokenBurner {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃           State Variables        ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice FeeHandler contract storing withdrawable fee rewards.
    IFeeHandler public immutable feeHandler;

    /// @notice The token that will be bought and burned (PEC).
    IERC20Burnable public immutable burnToken;

    /// @notice PancakeSwap V3 Router used for token swaps.
    ISwapRouter public immutable swapRouter;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃           Constructor            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Deploys the TokenBurner contract.
     *
     * @param _burnToken The token that will be burned (PEC).
     * @param _feeHandler The FeeHandler storing accumulated rewards.
     * @param _router PancakeSwap V3 Router address.
     */
    constructor(address _burnToken, address _feeHandler, address _router) Ownable(msg.sender) {
        burnToken = IERC20Burnable(_burnToken);
        feeHandler = IFeeHandler(_feeHandler);
        swapRouter = ISwapRouter(_router);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Fee Withdraw Logic        ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Withdraws accumulated rewards from the FeeHandler.
     *
     * @dev
     * If the withdrawable balance is zero, the function exits silently.
     *
     * @param token The reward token to withdraw.
     */
    function withdrawFees(address token) external {
        uint256 withdrawAmount = feeHandler.getWithdrawableBalance(address(this), token);

        if (withdrawAmount == 0) revert NoWithdrawableBalance();

        feeHandler.withdraw(token);

        uint256 received = IERC20(token).balanceOf(address(this));

        emit FeesWithdrawn(token, received);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Swap + Burn Function       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Swaps reward tokens into burnToken (PEC) and burns them.
     *
     * @dev
     * Requirements:
     * - amountIn must be greater than zero
     * - swap path must end in burnToken
     *
     * @param tokenIn The reward token to swap.
     * @param amountIn Amount of tokenIn to swap.
     * @param path PancakeSwap V3 encoded path.
     * @param minOut Minimum acceptable burn token output (slippage protection).
     */
    function swapToBurnTokenAndBurn(address tokenIn, uint256 amountIn, bytes calldata path, uint256 minOut) external {
        if (amountIn == 0) revert InvalidAmount();

        address tokenOut = _decodeLastToken(path);

        if (tokenOut != address(burnToken)) {
            revert InvalidTokenOut(tokenOut);
        }

        IERC20(tokenIn).approve(address(swapRouter), amountIn);

        uint256 pecReceived = swapRouter.exactInput(
            ISwapRouter.ExactInputParams({
                path: path,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: minOut
            })
        );

        burnToken.burn(pecReceived);

        emit TokenSwappedAndBurned(tokenIn, amountIn, pecReceived);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Internal Utilities        ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Extracts the last token address from a PancakeSwapV3 encoded path.
     *
     * @dev
     * Path encoding:
     * tokenA (20 bytes) + fee (3 bytes) + tokenB (20 bytes) ...
     *
     * @param path Encoded swap path.
     * @return lastToken The final token in the path.
     */
    function _decodeLastToken(bytes calldata path) internal pure returns (address lastToken) {
        if (path.length < 20) revert InvalidPath();

        uint256 start = path.length - 20;

        assembly {
            lastToken := shr(96, calldataload(add(path.offset, start)))
        }
    }
}
