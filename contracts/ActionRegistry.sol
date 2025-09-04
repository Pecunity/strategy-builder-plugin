// SPDX-License-Identifier:MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IActionRegistry} from "contracts/interfaces/IActionRegistry.sol";

contract ActionRegistry is Ownable, IActionRegistry {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       StateVariable       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    mapping(address => bool) private isAllowedAction;

    constructor(address initialOwner) Ownable(initialOwner) {}

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃     Public Functions      ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc IActionRegistry
    function allowAction(address action) external onlyOwner {
        if (action == address(0)) {
            revert ZeroAddressNotValid();
        }

        isAllowedAction[action] = true;
        emit ActionAllowed(action);
    }

    /// @inheritdoc IActionRegistry
    function revokeAction(address action) external onlyOwner {
        if (!isAllowedAction[action]) {
            revert ActionNotRegistered();
        }

        isAllowedAction[action] = false;
        emit ActionRevoked(action);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       View Functions     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc IActionRegistry
    function isAllowed(address action) external view returns (bool) {
        return isAllowedAction[action];
    }
}
