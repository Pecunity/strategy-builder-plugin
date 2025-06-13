// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IAction is IERC165 {
    struct PluginExecution {
        address target;
        uint256 value;
        bytes data;
    }

    /// @notice the identifier should be equal to strategy version. version 1 => bytes4(1)
    function identifier() external pure returns (bytes4);
}
