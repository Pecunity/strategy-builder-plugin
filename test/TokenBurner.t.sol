// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TokenBurner} from "../contracts/burn/TokenBurner.sol";
import {IFeeHandler} from "../contracts/interfaces/IFeeHandler.sol";
import {ITokenBurner} from "../contracts/interfaces/ITokenBurner.sol";

contract TokenBurnerTest is Test {
    string BNB_FORK = vm.envString("BNB_FORK");
    uint256 bnbFork;

    TokenBurner public tokenBurner;

    MockFeeHandler public feeHandler;

    address constant PEC_TOKEN = 0x413c2834f02003752d6Cc0Bcd1cE85Af04D62fBE;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    address public constant PANCAKE_SWAP_V3_ROUTER = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;

    address public ADMIN = makeAddr("admin");

    function setUp() public {
        bnbFork = vm.createFork(BNB_FORK);
        vm.selectFork(bnbFork);

        feeHandler = new MockFeeHandler();
        tokenBurner = new TokenBurner(PEC_TOKEN, address(feeHandler), PANCAKE_SWAP_V3_ROUTER);
    }

    function test_withdraw_tokensWithdrawable() external {
        uint256 amount = 0.5 ether;
        deal(WBNB, ADMIN, amount);

        vm.startPrank(ADMIN);
        IERC20(WBNB).approve(address(feeHandler), amount);
        feeHandler.depositMock(address(tokenBurner), WBNB, amount);
        vm.stopPrank();

        tokenBurner.withdrawFees(WBNB);

        assertEq(IERC20(WBNB).balanceOf(address(tokenBurner)), amount);
    }

    function test_withdraw_noTokensWithdrawable() external {
        vm.expectRevert(ITokenBurner.NoWithdrawableBalance.selector);
        tokenBurner.withdrawFees(WBNB);
    }

    function test_swapToBurnTokenAndBurn_tokensWithdrawable() external {
        uint256 amount = 0.5 ether;
        deal(WBNB, ADMIN, amount);

        vm.startPrank(ADMIN);
        IERC20(WBNB).approve(address(feeHandler), amount);
        feeHandler.depositMock(address(tokenBurner), WBNB, amount);
        vm.stopPrank();

        tokenBurner.withdrawFees(WBNB);

        assertEq(IERC20(WBNB).balanceOf(address(tokenBurner)), amount);

        //burn tokens

        bytes memory path = abi.encodePacked(
            WBNB,
            uint24(100), // 0.01%
            USDC,
            uint24(500), // 0.05%
            PEC_TOKEN
        );

        tokenBurner.swapToBurnTokenAndBurn(WBNB, amount, path, 0);

        assertEq(IERC20(WBNB).balanceOf(address(tokenBurner)), 0);
        assertEq(IERC20(PEC_TOKEN).balanceOf(address(tokenBurner)), 0);
    }

    function test_swapToBurnTokenAndBurn_wrongPath() external {
        uint256 amount = 0.5 ether;
        deal(WBNB, ADMIN, amount);

        vm.startPrank(ADMIN);
        IERC20(WBNB).approve(address(feeHandler), amount);
        feeHandler.depositMock(address(tokenBurner), WBNB, amount);
        vm.stopPrank();

        tokenBurner.withdrawFees(WBNB);

        assertEq(IERC20(WBNB).balanceOf(address(tokenBurner)), amount);

        //burn tokens

        bytes memory path = abi.encodePacked(
            WBNB,
            uint24(100), // 0.01%
            USDC
        );

        vm.expectRevert(abi.encodeWithSelector(ITokenBurner.InvalidTokenOut.selector, USDC));
        tokenBurner.swapToBurnTokenAndBurn(WBNB, amount, path, 0);
    }

    function test_swapToBurnTokenAndBurn_invalidAmount() external {
        uint256 amount = 0;

        //burn tokens

        bytes memory path = abi.encodePacked(
            WBNB,
            uint24(100), // 0.01%
            USDC,
            uint24(500), // 0.05%
            PEC_TOKEN
        );

        vm.expectRevert(abi.encodeWithSelector(ITokenBurner.InvalidAmount.selector));
        tokenBurner.swapToBurnTokenAndBurn(WBNB, amount, path, 0);
    }
}

contract MockFeeHandler {
    // ┏━━━━━━━━━━━━━━━━━┓
    // ┃    Errors       ┃
    // ┗━━━━━━━━━━━━━━━━━┛

    error InvalidAmount();
    error ZeroAddressNotValid();
    error InvalidBeneficiary();
    error PrimaryTokenAlreadyActivated();
    error InvalidPercentageDistribution();
    error TokenNotAllowed();
    error InvalidPercentage();

    // ┏━━━━━━━━━━━━━━━━━━┓
    // ┃     Events       ┃
    // ┗━━━━━━━━━━━━━━━━━━┛

    event FeeHandled(
        address indexed token,
        uint256 totalFee,
        address beneficiary,
        address creator,
        uint256 beneficiaryFee,
        uint256 creatorFee,
        uint256 vaultFee,
        uint256 burnAmount
    );
    event FeeHandledETH(
        uint256 totalFee,
        address beneficiary,
        address creator,
        uint256 beneficiaryFee,
        uint256 creatorFee,
        uint256 vaultFee,
        uint256 burnAmount
    );
    event PrimaryTokenActivated(address token, address treasury, uint256 primaryTokenBurn, uint256 tokenBurn);
    event UpdatedVault(address vault);
    event UpdatedBurnerAddress(address burnerAddress);
    event UpdatedPercentages(uint256 beneficiary, uint256 creator, uint256 vault);
    event UpdatedTokenAllowance(address token, bool allowed);
    event UpdatedReduction(address reduction);
    event Withdrawn(address indexed receiver, address indexed token, uint256 amount);
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event DepositWithdrawn(address indexed user, address indexed token, uint256 amount);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Withdrawable Storage      ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice user => token => withdrawable balance
    mapping(address => mapping(address => uint256)) private _balances;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃          Mock Deposit Logic      ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Adds withdrawable token rewards for a user (TEST ONLY).
     *
     * @param user The receiver of the rewards
     * @param token Token address (address(0) for ETH)
     * @param amount Amount credited
     */
    function depositMock(address user, address token, uint256 amount) external payable {
        if (amount == 0) revert InvalidAmount();

        if (token == address(0)) {
            // ETH deposit must match msg.value
            require(msg.value == amount, "ETH value mismatch");
        } else {
            // Transfer tokens into mock
            IERC20(token).transferFrom(msg.sender, address(this), amount);
        }

        _balances[user][token] += amount;

        emit Deposit(user, token, amount);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Withdraw Implementation   ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Withdraws all accumulated rewards for msg.sender.
     *
     * @param token Token address (address(0) for ETH)
     */
    function withdraw(address token) external {
        uint256 amount = _balances[msg.sender][token];
        if (amount == 0) revert InvalidAmount();

        _balances[msg.sender][token] = 0;

        if (token == address(0)) {
            // Send ETH
            (bool success,) = msg.sender.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            // Send ERC20
            IERC20(token).transfer(msg.sender, amount);
        }

        emit Withdrawn(msg.sender, token, amount);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃           View Functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function getWithdrawableBalance(address user, address token) external view returns (uint256) {
        return _balances[user][token];
    }
}
