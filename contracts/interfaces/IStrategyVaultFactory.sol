// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IStrategyVaultFactory {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃           Events          ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    event VaultProxyDeployed(
        address indexed proxyAddress, address indexed owner, uint256 vaultIndex, uint256 timestamp
    );

    event ImplementationDeployed(address indexed implementation, uint256 timestamp);

    event ImplementationUpgraded(address indexed newImplementation, uint256 timestamp);

    event ConfigurationUpdated(address feeController, address feeHandler, address actionRegistry);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃      Write Functions      ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function deployVaultDeterministic(bytes32 salt) external returns (address proxyAddress);

    function setImplementation(address implementation) external;

    function setConfiguration(address feeController, address feeHandler, address actionRegistry) external;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       View Functions      ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function getImplementation() external view returns (address);

    function getDeployedVaultsCount() external view returns (uint256);

    function getDeployedVaults(uint256 offset, uint256 limit) external view returns (address[] memory);

    function getVaultAt(uint256 index) external view returns (address);

    function getUserVaults(address user) external view returns (address[] memory);

    function getUserVaultsCount(address user) external view returns (uint256);

    function getUserVaultAt(address user, uint256 index) external view returns (address);

    function isDeployedVault(address vault) external view returns (bool);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃      Public Variables     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function deployedVaults(uint256 index) external view returns (address);

    function userVaults(address user, uint256 index) external view returns (address);

    function vaultIndex(address vault) external view returns (uint256);
}
