// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAction {
    struct PluginExecution {
        address target;
        uint256 value;
        bytes data;
    }
}
