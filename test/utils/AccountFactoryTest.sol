// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {EntryPoint} from "@eth-infinitism/account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";
import {ModularAccount} from "modular-account/src/account/ModularAccount.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {ValidationConfigLib} from "@erc6900/reference-implementation/libraries/ValidationConfigLib.sol";
import {SingleSignerValidationModule} from "modular-account/src/modules/validation/SingleSignerValidationModule.sol";

contract AccountFactoryTest {
    ModularAccount public immutable ACCOUNT_IMPL;
    IEntryPoint public immutable ENTRY_POINT;
    address public immutable SINGLE_SIGNER_VALIDATION_MODULE;

    constructor(IEntryPoint _entryPoint, ModularAccount _accountImpl, address _singleSignerValidationModule) {
        ENTRY_POINT = _entryPoint;
        ACCOUNT_IMPL = _accountImpl;
        SINGLE_SIGNER_VALIDATION_MODULE = _singleSignerValidationModule;
    }

    function createAccount(address owner, uint256 salt, uint32 entityId) external returns (ModularAccount) {
        bytes32 combinedSalt = getSalt(owner, salt, entityId);

        // LibClone short-circuits if it's already deployed.
        (bool alreadyDeployed, address instance) =
            LibClone.createDeterministicERC1967(address(ACCOUNT_IMPL), combinedSalt);

        // short circuit if exists
        if (!alreadyDeployed) {
            bytes memory moduleInstallData = abi.encode(entityId, owner);
            // point proxy to actual implementation and init plugins
            ModularAccount(payable(instance)).initializeWithValidation(
                ValidationConfigLib.pack(SINGLE_SIGNER_VALIDATION_MODULE, entityId, true, true, true),
                new bytes4[](0),
                moduleInstallData,
                new bytes[](0)
            );
        }

        return ModularAccount(payable(instance));
    }

    function getSalt(address owner, uint256 salt, uint32 entityId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, salt, entityId));
    }
}
