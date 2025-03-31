// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FeeHandler} from "../src/FeeHandler.sol";
import {IFeeHandler} from "../src/interfaces/IFeeHandler.sol";
import {Token} from "../src/test/mocks/MockToken.sol";

contract FeeHandlerTest is Test {
    FeeHandler handler;

    address public OWNER = makeAddr("owner");
    address public BAD_ACTOR = makeAddr("bad-actor");
    address public FEE_PAYER = makeAddr("fee-payer");

    address public VAULT = makeAddr("vault");

    uint256 BENEFICARY_PERCENTAGE = 2000;
    uint256 CREATOR_PERCENTAGE = 500;
    uint256 VAULT_PERCENTAGE = 7500;

    function setUp() external {
        vm.prank(OWNER);
        handler = new FeeHandler(VAULT, BENEFICARY_PERCENTAGE, CREATOR_PERCENTAGE, VAULT_PERCENTAGE, OWNER);
    }

    function test_deployment_Success() external {
        assertEq(handler.vault(), VAULT);

        assertEq(handler.beneficiaryPercentage(), BENEFICARY_PERCENTAGE);
        assertEq(handler.creatorPercentage(), CREATOR_PERCENTAGE);
        assertEq(handler.vaultPercentage(), VAULT_PERCENTAGE);
    }

    function test_deployment_VaultZeroAddress() external {
        vm.expectRevert(IFeeHandler.ZeroAddressNotValid.selector);
        handler = new FeeHandler(address(0), BENEFICARY_PERCENTAGE, CREATOR_PERCENTAGE, VAULT_PERCENTAGE, OWNER);
    }

    function test_deployment_SumPercentageNotCorrect() external {
        vm.expectRevert(IFeeHandler.InvalidPercentageDistribution.selector);

        handler = new FeeHandler(VAULT, BENEFICARY_PERCENTAGE, CREATOR_PERCENTAGE, VAULT_PERCENTAGE + 1, OWNER);
    }

    function test_activatePrimaryToken_Success(address token, address treasury) external {
        vm.assume(treasury != address(0));
        vm.assume(token != address(0));

        vm.prank(OWNER);
        handler.activatePrimaryToken(token, treasury);

        assert(handler.primaryTokenActive());
        assertEq(handler.treasury(), treasury);
    }

    function test_activatePrimaryToken_AlreadyActive(address token, address treasury) external {
        vm.assume(treasury != address(0));
        vm.assume(token != address(0));

        vm.prank(OWNER);
        handler.activatePrimaryToken(token, treasury);

        vm.prank(OWNER);
        vm.expectRevert(IFeeHandler.PrimaryTokenAlreadyActivated.selector);
        handler.activatePrimaryToken(token, treasury);
    }

    function test_updateVault_Success(address newVault) external {
        vm.assume(newVault != address(0));

        vm.prank(OWNER);
        handler.updateVault(newVault);

        assertEq(handler.vault(), newVault);
    }

    function test_updateVault_ZeroAddress() external {
        vm.prank(OWNER);
        vm.expectRevert(IFeeHandler.ZeroAddressNotValid.selector);
        handler.updateVault(address(0));
    }

    function test_updatePercentages_Success(uint256 _beneficiary, uint256 _creator) external {
        uint256 modBeneficiary = bound(_beneficiary, 100, handler.PERCENTAGE_DIVISOR());
        uint256 modCreator = bound(_creator, 100, handler.PERCENTAGE_DIVISOR());

        vm.assume(modBeneficiary + modCreator < handler.PERCENTAGE_DIVISOR());

        uint256 modVault = handler.PERCENTAGE_DIVISOR() - (modBeneficiary + modCreator);

        vm.prank(OWNER);
        handler.updatePercentages(modBeneficiary, modCreator, modVault);

        assertEq(handler.beneficiaryPercentage(), modBeneficiary);
        assertEq(handler.creatorPercentage(), modCreator);
        assertEq(handler.vaultPercentage(), modVault);
    }

    function test_updatePercentages_InvalidPercentageDistribution(
        uint256 _beneficiary,
        uint256 _creator,
        uint256 _vault
    ) external {
        uint256 modBeneficiary = bound(_beneficiary, 100, handler.PERCENTAGE_DIVISOR());
        uint256 modCreator = bound(_creator, 100, handler.PERCENTAGE_DIVISOR());

        vm.assume(modBeneficiary + modCreator < handler.PERCENTAGE_DIVISOR());

        uint256 modVault = bound(
            _vault,
            handler.PERCENTAGE_DIVISOR() - (modBeneficiary + modCreator) + 1,
            type(uint256).max - modBeneficiary - modCreator
        );

        vm.prank(OWNER);
        vm.expectRevert(IFeeHandler.InvalidPercentageDistribution.selector);
        handler.updatePercentages(modBeneficiary, modCreator, modVault);
    }

    function test_updatePrimaryTokenDiscount_Success(uint256 discount) external {
        vm.assume(discount <= handler.MAX_PRIMARY_TOKEN_DISCOUNT());

        vm.prank(OWNER);
        handler.updatePrimaryTokenDiscount(discount);

        assertEq(handler.primaryTokenDiscount(), discount);
    }

    function test_updatePrimaryTokenDiscount_ExceedMaxDiscount(uint256 discount) external {
        vm.assume(discount > handler.MAX_PRIMARY_TOKEN_DISCOUNT());

        vm.prank(OWNER);
        vm.expectRevert(IFeeHandler.InvalidPrimaryTokenDiscount.selector);
        handler.updatePrimaryTokenDiscount(discount);
    }

    function test_updateTokenAllowance_Success(address token) external {
        vm.prank(OWNER);
        handler.updateTokenAllowance(token, true);

        assertEq(handler.tokenAllowed(token), true);
    }

    function test_handleFee_Success(uint256 amount, address beneficiary, address creator) external {
        uint256 _maxTokenSupply = 1000 * 1e18;
        vm.prank(FEE_PAYER);
        Token _token = new Token("test", "MT", _maxTokenSupply);

        uint256 _amount = bound(amount, 100, _maxTokenSupply);
        vm.assume(beneficiary != address(0));
        vm.assume(creator != address(0));

        vm.prank(OWNER);
        handler.updateTokenAllowance(address(_token), true);

        vm.startPrank(FEE_PAYER);
        _token.approve(address(handler), _amount);
        handler.handleFee(address(_token), _amount, beneficiary, creator);

        assert(_token.balanceOf(beneficiary) > 0);
        assert(_token.balanceOf(creator) > 0);
        assert(_token.balanceOf(VAULT) > 0);
    }

    function test_handleFee_NoValidToken(address beneficiary, address creator, uint256 amount) external {
        uint256 _maxTokenSupply = 1000 * 1e18;
        uint256 _amount = bound(amount, 100, _maxTokenSupply);
        vm.assume(beneficiary != address(0));
        vm.assume(creator != address(0));

        address token = makeAddr("token");

        vm.expectRevert(IFeeHandler.TokenNotAllowed.selector);
        handler.handleFee(token, _amount, beneficiary, creator);
    }

    function test_handleFee_InvalidAmount(address beneficiary, address creator) external {
        uint256 amount = 0;
        address token = makeAddr("token");
        vm.assume(beneficiary != address(0));
        vm.assume(creator != address(0));

        vm.startPrank(FEE_PAYER);
        vm.expectRevert(IFeeHandler.InvalidAmount.selector);

        handler.handleFee(token, amount, beneficiary, creator);
    }

    function test_handleFee_ZeroAddress(uint256 amount, address creator) external {
        vm.assume(amount > 0);

        address token = makeAddr("token");

        address beneficiary = address(0);

        vm.startPrank(FEE_PAYER);
        vm.expectRevert(IFeeHandler.InvalidBeneficiary.selector);

        handler.handleFee(token, amount, beneficiary, creator);
    }

    function test_handleFee_PrimaryTokenActive(uint256 amount, address beneficiary, address creator) external {
        address primaryToken = makeAddr("primary-token");
        address treasury = makeAddr("treasury");

        uint256 _maxTokenSupply = 1000 * 1e18;
        vm.prank(FEE_PAYER);
        Token _token = new Token("test", "MT", _maxTokenSupply);

        vm.startPrank(OWNER);
        handler.activatePrimaryToken(primaryToken, treasury);
        handler.updateTokenAllowance(address(_token), true);
        vm.stopPrank();

        uint256 _amount = bound(amount, 100, _maxTokenSupply);
        vm.assume(beneficiary != address(0));
        vm.assume(creator != address(0));

        vm.startPrank(FEE_PAYER);
        _token.approve(address(handler), _amount);
        handler.handleFee(address(_token), _amount, beneficiary, creator);

        assert(_token.balanceOf(beneficiary) > 0);
        assert(_token.balanceOf(creator) > 0);
        assert(_token.balanceOf(VAULT) > 0);
        assert(_token.balanceOf(treasury) > 0);
    }

    function test_handleFee_PrimaryTokenPayment(uint256 amount, address beneficiary, address creator) external {
        uint256 _maxTokenSupply = 1000 * 1e18;

        vm.prank(FEE_PAYER);
        Token primaryToken = new Token("test", "MT", _maxTokenSupply);
        address treasury = makeAddr("treasury");

        vm.startPrank(OWNER);
        handler.activatePrimaryToken(address(primaryToken), treasury);
        handler.updateTokenAllowance(address(primaryToken), true);
        vm.stopPrank();

        uint256 _amount = bound(amount, 100, _maxTokenSupply);
        vm.assume(beneficiary != address(0));
        vm.assume(creator != address(0));

        vm.startPrank(FEE_PAYER);
        primaryToken.approve(address(handler), _amount);
        handler.handleFee(address(primaryToken), _amount, beneficiary, creator);

        assert(primaryToken.balanceOf(beneficiary) > 0);
        assert(primaryToken.balanceOf(creator) > 0);
        assert(primaryToken.balanceOf(VAULT) > 0);
        assert(primaryToken.balanceOf(treasury) == 0);
    }

    function test_handleFeeETH_Success(uint256 amount) external {
        uint256 maxAmountETH = 1000 * 1e18;
        deal(FEE_PAYER, maxAmountETH);

        vm.prank(OWNER);
        handler.updateTokenAllowance(address(0), true);

        uint256 _amount = bound(amount, 100, maxAmountETH);
        address beneficiary = makeAddr("beneficiary");
        address creator = makeAddr("creator");

        vm.startPrank(FEE_PAYER);

        handler.handleFeeETH{value: _amount}(beneficiary, creator);

        assert(beneficiary.balance > 0);
        assert(creator.balance > 0);
        assert(VAULT.balance > 0);
    }

    function test_handleFeeETH_ETHNotValid() external {
        address beneficiary = makeAddr("beneficiary");
        address creator = makeAddr("creator");

        vm.expectRevert(IFeeHandler.TokenNotAllowed.selector);
        handler.handleFeeETH(beneficiary, creator);
    }
}
