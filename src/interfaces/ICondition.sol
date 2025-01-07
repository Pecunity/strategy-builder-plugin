// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICondition {
    function checkCondition(address wallet, uint16 conditionId) external view returns (uint8);

    function isUpdateable(address wallet, uint16 conditionId) external view returns (bool);

    function updateCondition(uint16 conditionId) external returns (bool);
}
