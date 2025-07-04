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
    event Withdrawn(address indexed receiver, address indexed token, uint256 amount);

    /// @notice Handles ERC20 fee payment. Stores receivable amounts for beneficiary, creator, and vault.
    /// @param token The token address used for payment.
    /// @param amount The total fee amount sent by the user.
    /// @param beneficiary The fee beneficiary address.
    /// @param creator Optional creator address to receive part of the fee.
    /// @return totalAmount Total fee + burn amount recorded.
    function handleFee(address token, uint256 amount, address beneficiary, address creator)
        external
        returns (uint256);

    /// @notice Handles native ETH fee payment. Stores receivable ETH for withdrawal.
    /// @param beneficiary The fee beneficiary address.
    /// @param creator Optional creator address.
    /// @return totalAmount Total fee + burn amount recorded.
    function handleFeeETH(address beneficiary, address creator) external payable returns (uint256);

    /// @notice Allows a user to withdraw their accumulated fee balance for a given token.
    /// @param token The token address to withdraw (use address(0) for ETH).
    function withdraw(address token) external;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃            Admin Functions          ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Activates primary token for fee discounts.
    /// @param token Address of the primary token.
    /// @param treasury Address of the treasury.
    /// @param primaryTokenBurn The percenetage of primary token discount.
    /// @param primaryTokenBurn The percenetage of primary token burned.
    /// @param tokenBurn The percentage of token burned.
    function activatePrimaryToken(
        address token,
        address treasury,
        uint256 primaryTokenDiscount,
        uint256 primaryTokenBurn,
        uint256 tokenBurn
    ) external;

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

    /// @notice Returns the withdrawable balance for a given user and token.
    /// @param user The address of the user.
    /// @param token The token address (use address(0) for ETH).
    /// @return balance The amount the user can withdraw.
    function getWithdrawableBalance(address user, address token) external view returns (uint256 balance);
}
