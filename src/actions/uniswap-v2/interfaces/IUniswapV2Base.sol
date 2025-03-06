// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAction} from "../../../interfaces/IAction.sol";
import {ITokenGetter} from "../../../interfaces/ITokenGetter.sol";

interface IUniswapV2Base is IAction, ITokenGetter {
    error FailedToApproveTokens();
    error PoolPairDoesNotExist();
    error NotZeroAmountForBothTokensAllowed();
    error NoValidPercentageAmount();
    error NoZeroAmountValid();
    error InvalidTokenGetterID();
}
