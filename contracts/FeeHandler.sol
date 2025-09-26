// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IFeeHandler} from "./interfaces/IFeeHandler.sol";
import {IFeeReduction} from "./interfaces/IFeeReduction.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @title FeeHandler
/// @notice Handles fee distribution logic between beneficiary, creator, vault, and treasury.
/// @dev Supports both ERC20 tokens and native ETH fee handling with optional fee reduction and primary token discounts.
contract FeeHandler is Ownable, IFeeHandler {
    using SafeTransferLib for address;

    // ┏━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   State Variables    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━┛

    // @notice Address of the primary token for fee discounts.
    address public primaryToken;

    /// @notice Divisor for percentage calculations (10000 = 100%).
    uint256 public constant PERCENTAGE_DIVISOR = 10000;

    /// @notice Maximum discount allowed for primary token fees (50%).
    uint256 public constant MAX_PRIMARY_TOKEN_DISCOUNT = 5000;

    /// @notice Address of the vault where fees are stored.
    address public vault;

    /// @notice Address of the contract where fees are burned.
    address public burnerAddress;

    /// @notice Address of the reduction contract for user-specific fee reduction.
    address public reduction;

    /// @notice Percentage share for the fee beneficiary.
    uint256 public beneficiaryPercentage;

    /// @notice Percentage share for the fee creator.
    uint256 public creatorPercentage;

    /// @notice Percentage share for the vault.
    uint256 public vaultPercentage;

    /// @notice Discount in percentage when pay with primary token
    uint256 public primaryTokenDiscount;

    /// @notice Percentage of primary token burned.
    uint256 public primaryTokenBurn;

    /// @notice Percentage of non primary token burned.
    uint256 public tokenBurn;

    /// @notice Mapping of allowed tokens for fee payment.
    mapping(address token => bool) private allowedTokens;

    /// @notice Tracks withdrawable balances for each receiver adress and token
    mapping(address receiver => mapping(address token => uint256)) private withdrawableBalances;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃              Constructor            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @param _vault Address of the vault.
    /// @param _beneficaryPercentage Percentage share for the beneficiary.
    /// @param _creatorPercentage Percentage share for the creator.
    /// @param _vaultPercentage Percentage share for the vault.
    constructor(
        address _initialOwner,
        address _vault,
        uint256 _beneficaryPercentage,
        uint256 _creatorPercentage,
        uint256 _vaultPercentage
    ) Ownable(_initialOwner) {
        _updateVault(_vault);
        _updatePercentages(_beneficaryPercentage, _creatorPercentage, _vaultPercentage); // Default percentages: 30% beneficiary, 20% creator, 50% vault
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃      Public Functions     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc IFeeHandler
    function handleFee(address token, uint256 amount, address beneficiary, address creator)
        external
        returns (uint256)
    {
        _validateAmount(amount);
        _validateBeneficiary(beneficiary);

        if (!allowedTokens[token]) {
            revert TokenNotAllowed();
        }

        (uint256 totalFee, uint256 burnAmount) = _feeCalculation(amount, token);

        (uint256 beneficiaryAmount, uint256 creatorAmount, uint256 vaultAmount) = _tokenDistribution(totalFee);

        withdrawableBalances[beneficiary][token] += beneficiaryAmount;

        if (creator != address(0)) {
            withdrawableBalances[creator][token] += creatorAmount;
            withdrawableBalances[vault][token] += vaultAmount;
        } else {
            withdrawableBalances[vault][token] += vaultAmount + creatorAmount;
        }

        if (burnAmount > 0) {
            withdrawableBalances[burnerAddress][token] += burnAmount;
        }

        // Collect total funds from sender
        uint256 requiredAmount = totalFee + burnAmount;
        token.safeTransferFrom(msg.sender, address(this), requiredAmount);

        emit FeeHandled(
            token, totalFee, beneficiary, creator, beneficiaryAmount, creatorAmount, vaultAmount, burnAmount
        );

        return requiredAmount;
    }

    /// @inheritdoc IFeeHandler
    function handleFeeETH(address beneficiary, address creator) external payable returns (uint256) {
        if (!allowedTokens[address(0)]) {
            revert TokenNotAllowed();
        }

        _validateBeneficiary(beneficiary);

        uint256 amount = msg.value;
        _validateAmount(amount);

        (uint256 totalFee, uint256 burnAmount) = _feeCalculation(amount, address(0));
        (uint256 beneficiaryAmount, uint256 creatorAmount, uint256 vaultAmount) = _tokenDistribution(totalFee);

        withdrawableBalances[beneficiary][address(0)] += beneficiaryAmount;

        if (creator != address(0)) {
            withdrawableBalances[creator][address(0)] += creatorAmount;
            withdrawableBalances[vault][address(0)] += vaultAmount;
        } else {
            withdrawableBalances[vault][address(0)] += vaultAmount + creatorAmount;
        }

        if (burnAmount > 0) {
            withdrawableBalances[burnerAddress][address(0)] += burnAmount;
        }

        uint256 requiredAmount = totalFee + burnAmount;
        uint256 excess = msg.value > requiredAmount ? msg.value - requiredAmount : 0;

        if (excess > 0) {
            msg.sender.safeTransferETH(excess);
        }

        emit FeeHandledETH(totalFee, beneficiary, creator, beneficiaryAmount, creatorAmount, vaultAmount, burnAmount);

        return requiredAmount;
    }

    /// @inheritdoc IFeeHandler
    function withdraw(address token) external {
        uint256 amount = withdrawableBalances[msg.sender][token];
        if (amount == 0) revert InvalidAmount();
        withdrawableBalances[msg.sender][token] = 0;

        if (token == address(0)) {
            msg.sender.safeTransferETH(amount);
        } else {
            token.safeTransfer(msg.sender, amount);
        }

        emit Withdrawn(msg.sender, token, amount);
    }

    /// @inheritdoc IFeeHandler
    function activatePrimaryToken(
        address _token,
        address _burnerAddress,
        uint256 _primaryTokenDiscount,
        uint256 _primaryTokenBurn,
        uint256 _tokenBurn
    ) external onlyOwner {
        if (primaryTokenActive()) revert PrimaryTokenAlreadyActivated();
        _validateAddress(_token);
        _validateAddress(_burnerAddress);

        _validatePercentage(_primaryTokenBurn);
        _validatePercentage(_tokenBurn);
        _validatePercentage(_primaryTokenDiscount);
        if (_primaryTokenDiscount > MAX_PRIMARY_TOKEN_DISCOUNT) revert InvalidPercentage();

        primaryToken = _token;
        burnerAddress = _burnerAddress;

        primaryTokenDiscount = _primaryTokenDiscount;
        primaryTokenBurn = _primaryTokenBurn;
        tokenBurn = _tokenBurn;

        emit PrimaryTokenActivated(_token, _burnerAddress, _primaryTokenBurn, _tokenBurn);
    }

    /// @inheritdoc IFeeHandler
    function updateVault(address _vault) external onlyOwner {
        _updateVault(_vault);
    }

    /// @inheritdoc IFeeHandler
    function updateReduction(address _reduction) external onlyOwner {
        _validateAddress(_reduction);
        reduction = _reduction;
        emit UpdatedReduction(_reduction);
    }

    function updateBurnerAddress(address _burnerAddress) external onlyOwner {
        _updateBurnerAddress(_burnerAddress);
    }

    /// @inheritdoc IFeeHandler
    function updatePercentages(uint256 _beneficiary, uint256 _creator, uint256 _vault) external onlyOwner {
        _updatePercentages(_beneficiary, _creator, _vault);
    }

    /// @inheritdoc IFeeHandler
    function updateTokenAllowance(address token, bool allowed) external onlyOwner {
        allowedTokens[token] = allowed;

        emit UpdatedTokenAllowance(token, allowed);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Internal Functions     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _updateVault(address _vault) internal {
        _validateAddress(_vault);
        vault = _vault;
        emit UpdatedVault(_vault);
    }

    function _updateBurnerAddress(address _burnerAddress) internal {
        _validateAddress(_burnerAddress);
        burnerAddress = _burnerAddress;
        emit UpdatedBurnerAddress(_burnerAddress);
    }

    function _updatePercentages(uint256 _beneficiary, uint256 _creator, uint256 _vault) internal {
        if (_beneficiary + _creator + _vault != PERCENTAGE_DIVISOR) revert InvalidPercentageDistribution();
        beneficiaryPercentage = _beneficiary;
        creatorPercentage = _creator;
        vaultPercentage = _vault;
        emit UpdatedPercentages(_beneficiary, _creator, _vault);
    }

    function _tokenDistribution(uint256 amount)
        internal
        view
        returns (uint256 beneficiaryAmount, uint256 creatorAmount, uint256 vaultAmount)
    {
        beneficiaryAmount = (amount * beneficiaryPercentage) / PERCENTAGE_DIVISOR;
        creatorAmount = (amount * creatorPercentage) / PERCENTAGE_DIVISOR;
        vaultAmount = amount - beneficiaryAmount - creatorAmount;
    }

    function _feeCalculation(uint256 amount, address token)
        internal
        view
        returns (uint256 totalFee, uint256 burnAmount)
    {
        totalFee = amount;

        if (reduction != address(0)) {
            uint256 reductionPercentage = IFeeReduction(reduction).getFeeReduction(msg.sender);
            totalFee = totalFee - totalFee * reductionPercentage / PERCENTAGE_DIVISOR;
        }

        //The amount of burn varies if the primary token is used or not. If no primary token is activated, no tokens will be burned.
        if (primaryTokenActive()) {
            if (token == primaryToken) {
                totalFee = totalFee - totalFee * primaryTokenDiscount / PERCENTAGE_DIVISOR;
            }
            burnAmount = token == primaryToken
                ? (totalFee * primaryTokenBurn) / PERCENTAGE_DIVISOR
                : (totalFee * tokenBurn) / PERCENTAGE_DIVISOR;
            totalFee -= burnAmount;
        }
    }

    function _validateAddress(address _addr) internal pure {
        if (_addr == address(0)) {
            revert ZeroAddressNotValid();
        }
    }

    function _validateAmount(uint256 amount) internal pure {
        if (amount == 0) revert InvalidAmount();
    }

    function _validateBeneficiary(address beneficiary) internal pure {
        if (beneficiary == address(0)) revert InvalidBeneficiary();
    }

    function _validatePercentage(uint256 percentage) internal pure {
        if (percentage > PERCENTAGE_DIVISOR || percentage == 0) revert InvalidPercentage();
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    View Functions     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc IFeeHandler
    function primaryTokenActive() public view returns (bool) {
        return primaryToken != address(0);
    }

    /// @inheritdoc IFeeHandler
    function tokenAllowed(address token) external view returns (bool) {
        return allowedTokens[token];
    }

    /// @inheritdoc IFeeHandler
    function getWithdrawableBalance(address user, address token) external view returns (uint256 balance) {
        return withdrawableBalances[user][token];
    }
}
