// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPluginExecutor} from "modular-account-libs/interfaces/IPluginExecutor.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";

library AaveV3ExecutionLib {
    function supply(address wallet, address pool, address asset, uint256 amount) internal {
        bytes memory _data = abi.encodeCall(IPool.supply, (asset, amount, wallet, 0));

        IPluginExecutor(wallet).executeFromPluginExternal(pool, 0, _data);
    }

    function borrow(address wallet, address pool, address asset, uint256 amount, uint256 interestRateMode) internal {
        bytes memory _data = abi.encodeCall(IPool.borrow, (asset, amount, interestRateMode, 0, msg.sender));
        IPluginExecutor(wallet).executeFromPluginExternal(pool, 0, _data);
    }

    function depositETH(address wallet, address _WETH, uint256 amount) internal {}

    function withdrawETH(address wallet, address _WETH, uint256 amount) internal {}
}
