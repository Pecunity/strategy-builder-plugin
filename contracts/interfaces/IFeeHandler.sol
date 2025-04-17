// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IFeeHandler {
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

    /// @notice Handles fee distribution for ERC20 tokens.
    /// @param token Address of the ERC20 token used for payment.
    /// @param amount Total fee amount.
    /// @param beneficiary Address receiving the beneficiary share.
    /// @param creator Address receiving the creator share.
    function handleFee(address token, uint256 amount, address beneficiary, address creator) external;

    /// @notice Handles fee distribution for native ETH payments.
    /// @param beneficiary Address receiving the beneficiary share.
    /// @param creator Address receiving the creator share.
    function handleFeeETH(address beneficiary, address creator) external payable;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃            Admin Functions          ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Activates primary token for fee discounts.
    /// @param token Address of the primary token.
    /// @param treasury Address of the treasury.
    /// @param primaryTokenBurn The percenetage of primary token burned.
    /// @param tokenBurn The percentage of token burned.
    function activatePrimaryToken(address token, address treasury, uint256 primaryTokenBurn, uint256 tokenBurn)
        external;

    /// @notice Updates vault address.
    /// @param vault New vault address.
    function updateVault(address vault) external;

    /// @notice Updates reduction contract address.
    /// @param reduction New reduction contract address.
    function updateReduction(address reduction) external;

    /// @notice Updates fee distribution percentages.
    /// @param beneficiary Beneficiary percentage.
    /// @param creator Creator percentage.
    /// @param vault Vault percentage.
    function updatePercentages(uint256 beneficiary, uint256 creator, uint256 vault) external;

    /// @notice Updates token allowance for fee payment.
    /// @param token Token address.
    /// @param allowed Boolean indicating if the token is allowed.
    function updateTokenAllowance(address token, bool allowed) external;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃          View / Utility             ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Returns true if a primary token is active.
    /// @return active Boolean indicating if primary token is active.
    function primaryTokenActive() external view returns (bool);

    /// @notice Returns true if a token is allowed for payment.
    /// @param token Token address.
    /// @return allowed Boolean indicating if token is allowed.
    function tokenAllowed(address token) external view returns (bool);
}
