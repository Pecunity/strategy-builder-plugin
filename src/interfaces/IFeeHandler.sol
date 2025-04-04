// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IFeeHandler {
    error InvalidAmount();
    error ZeroAddressNotValid();
    error InvalidBeneficiary();
    error PrimaryTokenAlreadyActivated();
    error InvalidPercentageDistribution();
    error InvalidPrimaryTokenDiscount();
    error TokenNotAllowed();

    event FeeHandled(address indexed token, uint256 amount);
    event FeeHandledETH(uint256 amount);
    event PrimaryTokenActivated(address token, address treasury);
    event UpdatedVault(address vault);
    event UpdatedPercentages(uint256 beneficiary, uint256 creator, uint256 vault);
    event UpdatedPrimaryTokenDiscount(uint256 discount);
    event UpdatedTokenAllowance(address token, bool allowed);
    event UpdatedReduction(address reduction);

    function handleFee(address token, uint256 amount, address beneficiary, address creator) external;
    function handleFeeETH(address beneficiary, address creator) external payable;
    function activatePrimaryToken(address token, address _treasury) external;
    function updateVault(address _vault) external;
    function updatePercentages(uint256 _beneficiary, uint256 _creator, uint256 _vault) external;
    function updatePrimaryTokenDiscount(uint256 _discount) external;
    function updateTokenAllowance(address token, bool allowed) external;
    function tokenAllowed(address token) external view returns (bool);
}
