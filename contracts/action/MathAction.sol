// SPDX-License-Identifier:MIT
pragma solidity ^0.8.28;

import {IAction} from "../interfaces/IAction.sol";
import {IStrategyBuilderModule} from "../interfaces/IStrategyBuilderModule.sol";

contract MathAction is IAction {
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

    address public immutable strategyBuilderModule;

    constructor(address _strategyBuilderModule) {
        strategyBuilderModule = _strategyBuilderModule;
    }

    function execute(address wallet, bytes32 contextId, MathParams calldata param, uint256 input)
        public
        view
        returns (uint256)
    {
        uint256 A = input > 0
            ? input
            : param.a == bytes32(0)
                ? 0
                : abi.decode(
                    IStrategyBuilderModule(strategyBuilderModule).getContextVariable(wallet, contextId, param.a), (uint256)
                );

        uint256 B = abi.decode(
            IStrategyBuilderModule(strategyBuilderModule).getContextVariable(wallet, contextId, param.b), (uint256)
        );

        uint256 result;

        if (param.op == Op.ADD) {
            unchecked {
                result = A + B;
            }
        } else if (param.op == Op.SUB) {
            result = (A >= B ? A - B : 0);
        } else if (param.op == Op.MUL) {
            result = A * B;
        } else if (param.op == Op.DIV) {
            require(B > 0, "DIV by zero");
            result = A / B;
        }

        return result;
    }

    function executeBatch(address wallet, bytes32 contextId, MathParams[] calldata params)
        external
        view
        returns (uint256)
    {
        uint256 currentResult = 0;

        for (uint256 i = 0; i < params.length; i++) {
            uint256 _result = execute(wallet, contextId, params[i], currentResult);
            currentResult = _result;
        }

        return currentResult;
    }

    function identifier() external pure override returns (bytes4) {
        return bytes4(keccak256("math-action-1.0.0"));
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IAction).interfaceId;
    }
}
