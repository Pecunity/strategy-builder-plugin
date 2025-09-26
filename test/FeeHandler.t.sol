// SPDX-License-Identifier:MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FeeHandler} from "contracts/FeeHandler.sol";
import {IFeeHandler} from "contracts/interfaces/IFeeHandler.sol";
import {Token} from "contracts/test/mocks/MockToken.sol";
import {IFeeReduction} from "contracts/interfaces/IFeeReduction.sol";

contract FeeHandlerTest is Test {
    FeeHandler handler;

    address public OWNER = makeAddr("owner");
    address public BAD_ACTOR = makeAddr("bad-actor");
    address public FEE_PAYER = makeAddr("fee-payer");

    address public VAULT = makeAddr("vault");

    uint256 BENEFICARY_PERCENTAGE = 2000;
    uint256 CREATOR_PERCENTAGE = 500;
    uint256 VAULT_PERCENTAGE = 7500;
    uint256 PRIMARY_TOKEN_DISCOUNT = 2000;

    uint256 public constant BURN_PERCENTAGE = 1000;
    uint256 public constant PRIMARY_TOKEN_BURN_PERCENTAGE = 2000;

    function setUp() external {
        vm.prank(OWNER);
        handler = new FeeHandler(OWNER, VAULT, BENEFICARY_PERCENTAGE, CREATOR_PERCENTAGE, VAULT_PERCENTAGE);
    }

    function test_deployment_Success() external {
        assertEq(handler.vault(), VAULT);

        assertEq(handler.beneficiaryPercentage(), BENEFICARY_PERCENTAGE);
        assertEq(handler.creatorPercentage(), CREATOR_PERCENTAGE);
        assertEq(handler.vaultPercentage(), VAULT_PERCENTAGE);
    }

    function test_deployment_VaultZeroAddress() external {
        vm.expectRevert(IFeeHandler.ZeroAddressNotValid.selector);
        handler = new FeeHandler(OWNER, address(0), BENEFICARY_PERCENTAGE, CREATOR_PERCENTAGE, VAULT_PERCENTAGE);
    }

    function test_deployment_SumPercentageNotCorrect() external {
        vm.expectRevert(IFeeHandler.InvalidPercentageDistribution.selector);

        handler = new FeeHandler(OWNER, VAULT, BENEFICARY_PERCENTAGE, CREATOR_PERCENTAGE, VAULT_PERCENTAGE + 1);
    }

    function test_activatePrimaryToken_Success(address token, address burnerAddress) external {
        vm.assume(burnerAddress != address(0));
        vm.assume(token != address(0));

        vm.prank(OWNER);
        handler.activatePrimaryToken(
            token, burnerAddress, PRIMARY_TOKEN_DISCOUNT, PRIMARY_TOKEN_BURN_PERCENTAGE, BURN_PERCENTAGE
        );

        assertTrue(handler.primaryTokenActive());
        assertEq(handler.burnerAddress(), burnerAddress);
        assertEq(handler.primaryTokenBurn(), PRIMARY_TOKEN_BURN_PERCENTAGE);
        assertEq(handler.tokenBurn(), BURN_PERCENTAGE);
    }

    function test_activatePrimaryToken_AlreadyActive(address token, address burnerAddress) external {
        vm.assume(burnerAddress != address(0));
        vm.assume(token != address(0));

        vm.prank(OWNER);
        handler.activatePrimaryToken(
            token, burnerAddress, PRIMARY_TOKEN_DISCOUNT, PRIMARY_TOKEN_BURN_PERCENTAGE, BURN_PERCENTAGE
        );

        vm.prank(OWNER);
        vm.expectRevert(IFeeHandler.PrimaryTokenAlreadyActivated.selector);
        handler.activatePrimaryToken(
            token, burnerAddress, PRIMARY_TOKEN_DISCOUNT, PRIMARY_TOKEN_BURN_PERCENTAGE, BURN_PERCENTAGE
        );
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

        assert(handler.getWithdrawableBalance(beneficiary, address(_token)) > 0);
        assert(handler.getWithdrawableBalance(creator, address(_token)) > 0);
        assert(handler.getWithdrawableBalance(VAULT, address(_token)) > 0);
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
        address burnerAddress = makeAddr("burner-address");

        uint256 _maxTokenSupply = 1000 * 1e18;
        vm.prank(FEE_PAYER);
        Token _token = new Token("test", "MT", _maxTokenSupply);

        vm.startPrank(OWNER);
        handler.activatePrimaryToken(primaryToken, burnerAddress, PRIMARY_TOKEN_DISCOUNT, 1000, 2000);
        handler.updateTokenAllowance(address(_token), true);
        vm.stopPrank();

        uint256 _amount = bound(amount, 100, _maxTokenSupply);
        vm.assume(beneficiary != address(0));
        vm.assume(creator != address(0));

        vm.startPrank(FEE_PAYER);
        _token.approve(address(handler), _amount);
        handler.handleFee(address(_token), _amount, beneficiary, creator);

        assert(handler.getWithdrawableBalance(beneficiary, address(_token)) > 0);
        assert(handler.getWithdrawableBalance(creator, address(_token)) > 0);
        assert(handler.getWithdrawableBalance(VAULT, address(_token)) > 0);
        assert(handler.getWithdrawableBalance(burnerAddress, address(_token)) > 0);
    }

    function test_handleFee_PrimaryTokenPayment(uint256 amount, address beneficiary, address creator) external {
        uint256 _maxTokenSupply = 1000 * 1e18;

        vm.prank(FEE_PAYER);
        Token primaryToken = new Token("test", "MT", _maxTokenSupply);
        address burnerAddress = makeAddr("burner-address");

        vm.startPrank(OWNER);
        handler.activatePrimaryToken(
            address(primaryToken), burnerAddress, PRIMARY_TOKEN_DISCOUNT, PRIMARY_TOKEN_BURN_PERCENTAGE, BURN_PERCENTAGE
        );
        handler.updateTokenAllowance(address(primaryToken), true);
        vm.stopPrank();

        uint256 _amount = bound(amount, 100, _maxTokenSupply);
        vm.assume(beneficiary != address(0));
        vm.assume(creator != address(0));

        vm.startPrank(FEE_PAYER);
        primaryToken.approve(address(handler), _amount);
        handler.handleFee(address(primaryToken), _amount, beneficiary, creator);

        assert(handler.getWithdrawableBalance(beneficiary, address(primaryToken)) > 0);
        assert(handler.getWithdrawableBalance(creator, address(primaryToken)) > 0);
        assert(handler.getWithdrawableBalance(VAULT, address(primaryToken)) > 0);
        assert(handler.getWithdrawableBalance(burnerAddress, address(primaryToken)) > 0);
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

        assert(handler.getWithdrawableBalance(beneficiary, address(0)) > 0);
        assert(handler.getWithdrawableBalance(creator, address(0)) > 0);
        assert(handler.getWithdrawableBalance(VAULT, address(0)) > 0);
    }

    function test_handleFeeETH_Success_WithReduction(uint256 amount) external {
        uint256 maxAmountETH = 1000 * 1e18;
        deal(FEE_PAYER, maxAmountETH);

        vm.prank(OWNER);
        handler.updateTokenAllowance(address(0), true);

        address reduction = makeAddr("reduction");
        vm.prank(OWNER);
        handler.updateReduction(reduction);

        uint256 reductionPercentage = 1000; //10%
        vm.mockCall(
            reduction, abi.encodeCall(IFeeReduction.getFeeReduction, (FEE_PAYER)), abi.encode(reductionPercentage)
        );

        uint256 _amount = bound(amount, 100, maxAmountETH);
        address beneficiary = makeAddr("beneficiary");
        address creator = makeAddr("creator");

        vm.startPrank(FEE_PAYER);

        handler.handleFeeETH{value: _amount}(beneficiary, creator);

        assert(handler.getWithdrawableBalance(beneficiary, address(0)) > 0);
        assert(handler.getWithdrawableBalance(creator, address(0)) > 0);
        assert(handler.getWithdrawableBalance(VAULT, address(0)) > 0);
    }

    function test_handleFeeETH_ETHNotValid() external {
        address beneficiary = makeAddr("beneficiary");
        address creator = makeAddr("creator");

        vm.expectRevert(IFeeHandler.TokenNotAllowed.selector);
        handler.handleFeeETH(beneficiary, creator);
    }

    function test_withdraw_Success_ETH(uint256 amount) external {
        uint256 maxAmountETH = 1000 * 1e18;
        deal(FEE_PAYER, maxAmountETH);

        vm.prank(OWNER);
        handler.updateTokenAllowance(address(0), true);

        uint256 _amount = bound(amount, 100, maxAmountETH);
        address beneficiary = makeAddr("beneficiary");
        address creator = makeAddr("creator");

        vm.startPrank(FEE_PAYER);

        handler.handleFeeETH{value: _amount}(beneficiary, creator);
        vm.stopPrank();

        uint256 withdrawableETH = handler.getWithdrawableBalance(beneficiary, address(0));
        vm.prank(beneficiary);
        handler.withdraw(address(0));

        assert(beneficiary.balance == withdrawableETH);
    }

    function test_withdraw_Success_token(address beneficiary, address creator, uint256 amount) external {
        uint256 _maxTokenSupply = 1000 * 1e18;

        vm.assume(beneficiary != FEE_PAYER);
        vm.assume(creator != FEE_PAYER);

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

        vm.stopPrank();

        uint256 withdrawableToken = handler.getWithdrawableBalance(beneficiary, address(_token));
        vm.prank(beneficiary);
        handler.withdraw(address(_token));

        assert(_token.balanceOf(beneficiary) == withdrawableToken);
    }

    function test_withdraw_NoWithdrawAmount(uint256 amount) external {
        address beneficiary = makeAddr("beneficiary");
        address creator = makeAddr("creator");

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

        vm.stopPrank();

        vm.startPrank(BAD_ACTOR);
        vm.expectRevert(IFeeHandler.InvalidAmount.selector);
        handler.withdraw(address(_token));
    }
}
