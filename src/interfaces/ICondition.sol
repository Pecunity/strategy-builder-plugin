// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICondition {
    function checkCondition(address wallet, uint16 id) external view returns (uint8);

    function isUpdateable(address wallet, uint16 id) external view returns (bool);

    function actionValid(address wallet, uint16 id, uint16 action) external view returns (bool);

    function strategyValid(address wallet, uint16 id, uint16 strategy) external view returns (bool);

    function updateCondition(uint16 id) external returns (bool);

    function deleteCondition(uint16 id) external;

    function addAutomationToCondition(uint16 id, uint16 action) external returns (bool);

    function addStrategyToCondition(uint16 id, uint16 action) external returns (bool);

    function removeAutomationFromCondition(uint16 id, uint16 automation) external returns (bool);

    function removeStrategyFromCondition(uint16 id, uint16 strategy) external returns (bool);
}
