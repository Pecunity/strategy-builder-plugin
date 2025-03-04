// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IFeeHandler} from "./interfaces/IFeeHandler.sol";

contract FeeHandler is Ownable, IFeeHandler {
    using SafeERC20 for IERC20;

    uint256 public constant PERCENTAGE_DIVISOR = 10000;
    uint256 public constant MAX_PRIMARY_TOKEN_DISCOUNT = 5000;

    address public vault;
    address public treasury;
    address public primaryToken;

    uint256 public beneficiaryPercentage;
    uint256 public creatorPercentage;
    uint256 public vaultPercentage;
    uint256 public primaryTokenDiscount = 2000; // 20% expressed as 2000 / 10000

    mapping(address token => bool) private allowedTokens;

    constructor(address _vault, uint256 _beneficaryPercentage, uint256 _creatorPercentage, uint256 _vaultPercentage) {
        _updateVault(_vault);
        _updatePercentages(_beneficaryPercentage, _creatorPercentage, _vaultPercentage); // Default percentages: 30% beneficiary, 20% creator, 50% vault
    }

    function handleFee(address token, uint256 amount, address beneficiary, address creator) external {
        _validateAmount(amount);
        _validateBeneficiaryAndCreator(beneficiary, creator);

        uint256 totalFee = amount;
        uint256 feeDiscount = 0;
        uint256 treasuryFee = 0;

        if (primaryTokenActive() && token == primaryToken) {
            feeDiscount = (amount * primaryTokenDiscount) / PERCENTAGE_DIVISOR;
            totalFee -= feeDiscount;
        } else if (primaryTokenActive()) {
            treasuryFee = (amount * primaryTokenDiscount) / PERCENTAGE_DIVISOR;
            totalFee -= treasuryFee;
        }

        (uint256 beneficiaryAmount, uint256 creatorAmount, uint256 vaultAmount) = _tokenDistribution(totalFee);

        IERC20(token).safeTransferFrom(msg.sender, beneficiary, beneficiaryAmount);
        IERC20(token).safeTransferFrom(msg.sender, creator, creatorAmount);
        IERC20(token).safeTransferFrom(msg.sender, vault, vaultAmount);
        if (treasuryFee > 0) {
            IERC20(token).safeTransferFrom(msg.sender, treasury, treasuryFee);
        }

        emit FeeHandled(token, amount);
    }

    function handleFeeETH(address beneficiary, address creator) external payable {
        _validateBeneficiaryAndCreator(beneficiary, creator);

        uint256 totalFee = msg.value;
        _validateAmount(totalFee);

        (uint256 beneficiaryAmount, uint256 creatorAmount, uint256 vaultAmount) = _tokenDistribution(totalFee);

        payable(beneficiary).transfer(beneficiaryAmount);
        payable(creator).transfer(creatorAmount);
        payable(vault).transfer(vaultAmount);

        emit FeeHandledETH(msg.value);
    }

    function activatePrimaryToken(address _token, address _treasury) external onlyOwner {
        if (primaryTokenActive()) revert PrimaryTokenAlreadyActivated();
        _validateAddress(_token);
        _validateAddress(_treasury);
        primaryToken = _token;
        treasury = _treasury;
        emit PrimaryTokenActivated(_token, _treasury);
    }

    function updateVault(address _vault) external onlyOwner {
        _updateVault(_vault);
    }

    function updatePercentages(uint256 _beneficiary, uint256 _creator, uint256 _vault) external onlyOwner {
        _updatePercentages(_beneficiary, _creator, _vault);
    }

    function updatePrimaryTokenDiscount(uint256 _discount) external onlyOwner {
        if (_discount > MAX_PRIMARY_TOKEN_DISCOUNT) {
            revert InvalidPrimaryTokenDiscount();
        }
        primaryTokenDiscount = _discount;
        emit UpdatedPrimaryTokenDiscount(_discount);
    }

    function updateTokenAllowance(address token, bool allowed) external onlyOwner {
        allowedTokens[token] = allowed;

        emit UpdatedTokenAllowance(token, allowed);
    }

    function _updateVault(address _vault) internal {
        _validateAddress(_vault);
        vault = _vault;
        emit UpdatedVault(_vault);
    }

    function _updatePercentages(uint256 _beneficiary, uint256 _creator, uint256 _vault) internal {
        if (_beneficiary + _creator + _vault != PERCENTAGE_DIVISOR) revert InvalidPercentageDistribution();
        beneficiaryPercentage = _beneficiary;
        creatorPercentage = _creator;
        vaultPercentage = _vault;
        emit UpdatedPercentages(_beneficiary, _creator, _vault);
    }

    function _tokenDistribution(uint256 amount) internal view returns (uint256, uint256, uint256) {
        uint256 beneficiaryAmount = (amount * beneficiaryPercentage) / PERCENTAGE_DIVISOR;
        uint256 creatorAmount = (amount * creatorPercentage) / PERCENTAGE_DIVISOR;
        uint256 vaultAmount = (amount * vaultPercentage) / PERCENTAGE_DIVISOR;

        return (beneficiaryAmount, creatorAmount, vaultAmount);
    }

    function _validateAddress(address _addr) internal pure {
        if (_addr == address(0)) {
            revert ZeroAddressNotValid();
        }
    }

    function _validateAmount(uint256 amount) internal pure {
        if (amount == 0) revert InvalidAmount();
    }

    function _validateBeneficiaryAndCreator(address beneficiary, address creator) internal pure {
        if (beneficiary == address(0) || creator == address(0)) revert InvalidBeneficiaryOrCreator();
    }

    function primaryTokenActive() public view returns (bool) {
        return primaryToken != address(0);
    }

    function tokenAllowed(address token) external view returns (bool) {
        return allowedTokens[token];
    }
}
