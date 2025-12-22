// SPDX-License-Identifier:MIT
pragma solidity ^0.8.28;

import {IAction} from "../interfaces/IAction.sol";
import {IStrategyVault} from "../interfaces/IStrategyVault.sol";

contract MathActionVault is IAction {
    enum Op {
        ADD,
        SUB,
        MUL,
        DIV
    }

    struct MathParams {
        Op op;
        bytes32 a;
        bytes32 b;
    }

    function execute(address vault, bytes32 contextId, MathParams calldata param, uint256 input)
        public
        view
        returns (uint256)
    {
        // ---------------------------------
        // Determine A
        // ---------------------------------
        uint256 A;
        if (input > 0) {
            A = input;
        } else if (param.a == bytes32(0)) {
            A = 0;
        } else {
            bytes memory rawA = IStrategyVault(vault).getContextVariable(contextId, param.a);

            A = rawA.length == 0 ? 0 : abi.decode(rawA, (uint256));
        }

        // ---------------------------------
        // Determine B (always taken from context)
        // ---------------------------------
        uint256 B;
        if (param.b == bytes32(0)) {
            B = 0;
        } else {
            bytes memory rawB = IStrategyVault(vault).getContextVariable(contextId, param.a);

            B = rawB.length == 0 ? 0 : abi.decode(rawB, (uint256));
        }

        // ---------------------------
        // Execute operation
        // ---------------------------
        if (param.op == Op.ADD) {
            unchecked {
                return A + B;
            }
        } else if (param.op == Op.SUB) {
            return A >= B ? A - B : 0;
        } else if (param.op == Op.MUL) {
            return A * B;
        } else if (param.op == Op.DIV) {
            // Return 0 instead of revert
            return B == 0 ? 0 : A / B;
        }

        // Unknown op → return 0 safely instead of reverting
        return 0;
    }

    function executeBatch(address vault, bytes32 contextId, MathParams[] calldata params)
        external
        view
        returns (uint256)
    {
        uint256 currentResult = 0;

        for (uint256 i = 0; i < params.length; i++) {
            uint256 _result = execute(vault, contextId, params[i], currentResult);
            currentResult = _result;
        }

        return currentResult;
    }

    function identifier() external pure override returns (bytes4) {
        return bytes4(keccak256("math-action-vault-1.0.0"));
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IAction).interfaceId;
    }
}
