// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import {IPluginExecutor} from "modular-account-libs/interfaces/IPluginExecutor.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// error ERC20PluginLib__FailedToApproveTokens();

// library ERC20PluginLib {
//     function approveToken(address wallet, address spender, address token, uint256 amount) internal {
//         bytes memory _data = abi.encodeCall(IERC20.approve, (spender, amount));
//         bytes memory _res = IPluginExecutor(wallet).executeFromPluginExternal(token, 0, _data);
//         bool success = abi.decode(_res, (bool));

//         if (!success) {
//             revert ERC20PluginLib__FailedToApproveTokens();
//         }
//     }
// }
