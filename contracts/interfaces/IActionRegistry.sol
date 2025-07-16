// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IActionRegistry
/// @notice Interface for managing and validating allowed action contract addresses.
/// @dev Used to whitelist and check access for external action contracts.
interface IActionRegistry {
    // ┏━━━━━━━━━━━━━━━━━┓
    // ┃    Errors       ┃
    // ┗━━━━━━━━━━━━━━━━━┛

    error ZeroAddressNotValid();
    error ActionNotRegistered();

    // ┏━━━━━━━━━━━━━━━━━━┓
    // ┃     Events       ┃
    // ┗━━━━━━━━━━━━━━━━━━┛

    event ActionAllowed(address indexed action);
    event ActionRevoked(address indexed action);

    // ┏━━━━━━━━━━━━━━━━━━┓
    // ┃   Functions      ┃
    // ┗━━━━━━━━━━━━━━━━━━┛

    /// @notice Allows (whitelists) an action contract address.
    /// @dev Only callable by the owner or authorized entity.
    /// @param action The address of the action contract to allow.
    function allowAction(address action) external;

    /// @notice Revokes a previously allowed action contract address.
    /// @dev Only callable by the owner or authorized entity.
    /// @param action The address of the action contract to revoke.
    function revokeAction(address action) external;

    /// @notice Checks whether a given action contract address is allowed.
    /// @param action The address to check.
    /// @return allowed A boolean indicating whether the action is allowed.
    function isAllowed(address action) external view returns (bool);
}
