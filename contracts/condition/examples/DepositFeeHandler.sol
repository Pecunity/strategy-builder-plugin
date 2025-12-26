// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseCondition} from "../BaseCondition.sol";
import {IDepositFeeHandler} from "./interfaces/IDepoistFeeHandler.sol";
import {IFeeHandler} from "../../interfaces/IFeeHandler.sol";

contract DepositFeeHandler is BaseCondition, IDepositFeeHandler {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        State Variables           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    mapping(address wallet => mapping(uint32 id => Condition condition)) private conditions;

    address public immutable feeHandler;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃           Modifiers              ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    modifier validCondition(Condition calldata _condition) {
        if (_condition.comparison > Comparison.NOT_EQUAL) {
            revert InvalidComparison();
        }

        if (!IFeeHandler(feeHandler).tokenAllowed(_condition.depositToken)) {
            revert NoValidDepositToken();
        }
        _;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor      ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━┛

    constructor(address _feeHandler) {
        feeHandler = _feeHandler;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Public Functions           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    function addCondition(uint32 _id, Condition calldata condition) external validCondition(condition) {
        conditions[msg.sender][_id] = condition;

        _addCondition(_id);

        emit ConditionAdded(_id, msg.sender, condition);
    }

    function deleteCondition(uint32 _id) public override {
        super.deleteCondition(_id);
        delete conditions[msg.sender][_id];

        emit ConditionDeleted(_id, msg.sender);
    }

    function updateCondition(uint32 _id) public view override returns (bool) {
        return conditions[msg.sender][_id].updateable;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃         View Functions           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function checkCondition(address wallet, uint32 id) public view override returns (uint8) {
        Condition memory condition = conditions[wallet][id];

        //Get the actual health factor of the wallet
        uint256 tokenBalance = IFeeHandler(feeHandler).getDeposit(condition.account, condition.depositToken);

        if (condition.comparison == Comparison.GREATER || condition.comparison == Comparison.GREATER_OR_EQUAL) {
            if (tokenBalance > condition.amount) {
                return 1;
            }
        }

        if (condition.comparison == Comparison.LESS || condition.comparison == Comparison.LESS_OR_EQUAL) {
            if (tokenBalance < condition.amount) {
                return 1;
            }
        }

        if (
            condition.comparison == Comparison.EQUAL || condition.comparison == Comparison.GREATER_OR_EQUAL
                || condition.comparison == Comparison.LESS_OR_EQUAL
        ) {
            if (tokenBalance == condition.amount) {
                return 1;
            }
        }

        if (condition.comparison == Comparison.NOT_EQUAL) {
            if (tokenBalance != condition.amount) {
                return 1;
            }
        }

        return 0;
    }

    function isUpdateable(address wallet, uint32 id) public view override returns (bool) {
        return conditions[wallet][id].updateable;
    }

    function walletCondition(address _wallet, uint32 _id) public view returns (Condition memory) {
        return conditions[_wallet][_id];
    }
}
