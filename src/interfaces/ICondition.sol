// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICondition {
    function checkCondition(address wallet, uint32 id) external view returns (uint8);

    function isUpdateable(address wallet, uint32 id) external view returns (bool);

    function actionValid(address wallet, uint32 id, uint32 action) external view returns (bool);

    function strategyValid(address wallet, uint32 id, uint32 strategy) external view returns (bool);

    function updateCondition(uint32 id) external returns (bool);

    function deleteCondition(uint32 id) external;

    function addAutomationToCondition(uint32 id, uint32 action) external returns (bool);

    function addStrategyToCondition(uint32 id, uint32 action) external returns (bool);

    function removeAutomationFromCondition(uint32 id, uint32 automation) external returns (bool);

    function removeStrategyFromCondition(uint32 id, uint32 strategy) external returns (bool);

    function conditionActive(address wallet, uint32 id) external view returns (bool);
}
