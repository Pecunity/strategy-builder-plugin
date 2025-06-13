// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAction} from "../../interfaces/IAction.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockAction is IAction {
    function execute(address[] memory targets, address token, uint256 val)
        external
        pure
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](targets.length);
        for (uint256 i; i < targets.length; i++) {
            executions[i] = PluginExecution(token, 0, abi.encodeCall(IERC20.transfer, (targets[i], val)));
        }
        return executions;
    }

    function identifier() external pure returns (bytes4) {
        return bytes4(uint32(1));
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IAction).interfaceId;
    }
}
