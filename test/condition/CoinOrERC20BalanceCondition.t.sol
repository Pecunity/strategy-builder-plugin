// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CoinOrERC20BalanceCondition} from "src/condition/CoinOrERC20BalanceCondition.sol";
import {ICoinOrERC20BalanceCondition} from "src/condition/interfaces/ICoinOrERC20BalanceCondition.sol";

contract CoinOrERC20BalanceConditionTest is Test {
    CoinOrERC20BalanceCondition condition;

    address public WALLET = makeAddr("wallet");
    uint32 public conditionId = 123456;

    address public token = makeAddr("token");

    function setUp() public {
        condition = new CoinOrERC20BalanceCondition();
    }

    function test_addCondition_GreaterThan_Success(uint256 balance) public {
        vm.assume(balance > 0); // Ensure balance is greater than zero

        ICoinOrERC20BalanceCondition.Condition memory conditionData = ICoinOrERC20BalanceCondition.Condition({
            amount: balance,
            comparison: ICoinOrERC20BalanceCondition.Comparison.GREATER,
            updateable: true,
            baseToken: token
        });

        vm.prank(WALLET);
        condition.addCondition(conditionId, conditionData);

        assertEq(condition.walletCondition(WALLET, conditionId).amount, balance);
        assertEq(
            uint8(condition.walletCondition(WALLET, conditionId).comparison),
            uint8(ICoinOrERC20BalanceCondition.Comparison.GREATER)
        );
        assertEq(condition.walletCondition(WALLET, conditionId).updateable, true);
        assertEq(condition.walletCondition(WALLET, conditionId).baseToken, token);
    }

    function test_isUptateable_ReturnCorrectValue(bool upateable) public {
        ICoinOrERC20BalanceCondition.Condition memory conditionData = ICoinOrERC20BalanceCondition.Condition({
            amount: 1000,
            comparison: ICoinOrERC20BalanceCondition.Comparison.GREATER,
            updateable: upateable,
            baseToken: token
        });

        vm.prank(WALLET);
        condition.addCondition(conditionId, conditionData);
        assertEq(condition.isUpdateable(WALLET, conditionId), upateable);
    }

    function test_upateCondition_Success(bool updatable) public {
        ICoinOrERC20BalanceCondition.Condition memory conditionData = ICoinOrERC20BalanceCondition.Condition({
            amount: 1000,
            comparison: ICoinOrERC20BalanceCondition.Comparison.GREATER,
            updateable: updatable,
            baseToken: token
        });
        vm.prank(WALLET);
        condition.addCondition(conditionId, conditionData);

        vm.prank(WALLET);
        bool update = condition.updateCondition(conditionId);

        assertEq(update, updatable);
    }

    function test_deleteCondition_Success() public {
        ICoinOrERC20BalanceCondition.Condition memory conditionData = ICoinOrERC20BalanceCondition.Condition({
            amount: 1000,
            comparison: ICoinOrERC20BalanceCondition.Comparison.GREATER,
            updateable: true,
            baseToken: token
        });
        vm.prank(WALLET);
        condition.addCondition(conditionId, conditionData);
        vm.prank(WALLET);
        condition.deleteCondition(conditionId);

        assertEq(condition.walletCondition(WALLET, conditionId).amount, 0);
    }

    function test_checkCondition_Return_True(uint256 _balance, uint8 _comparison) external {
        uint8 comparison = uint8(bound(_comparison, uint8(0), uint8(5)));
        uint256 balance = bound(_balance, 1, type(uint256).max - 1); // Ensure balance is greater than zero and less than 2^256

        ICoinOrERC20BalanceCondition.Condition memory conditionData = ICoinOrERC20BalanceCondition.Condition({
            amount: balance,
            comparison: ICoinOrERC20BalanceCondition.Comparison(comparison),
            updateable: true,
            baseToken: token
        });

        vm.prank(WALLET);
        condition.addCondition(conditionId, conditionData);

        uint256 mockBalance;
        if (comparison == 0 || comparison == 4 || comparison == 5) {
            mockBalance = balance - 1;
        } else if (comparison == 1 || comparison == 3) {
            mockBalance = balance + 1;
        } else {
            mockBalance = balance;
        }
        vm.mockCall(token, abi.encodeWithSelector(IERC20.balanceOf.selector, WALLET), abi.encode(mockBalance));
        uint8 result = condition.checkCondition(WALLET, conditionId);
        assertEq(result, 1);
    }
}
