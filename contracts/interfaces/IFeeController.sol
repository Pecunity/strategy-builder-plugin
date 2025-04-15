// SPDX-License-Identifier:MIT
pragma solidity ^0.8.26;

interface IFeeController {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃     Structs / Enums       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Enum representing the type of fee.
    enum FeeType {
        Deposit,
        Withdraw,
        Reward
    }

    /// @notice Struct containing fee configuration parameters.
    /// @param feeType The type of fee being applied.
    /// @param feePercentage The fee percentage in basis points (1% = 100).
    struct FeeConfig {
        FeeType feeType;
        uint256 feePercentage;
    }

    // ┏━━━━━━━━━━━━━━━━━┓
    // ┃    Errors       ┃
    // ┗━━━━━━━━━━━━━━━━━┛

    /// @notice Thrown when the specified fee percentage exceeds the allowed maximum limit.
    error FeePercentageExceedLimit();

    /// @notice Thrown when a provided address is the zero address.
    error ZeroAddressNotValid();

    /// @notice Thrown when no oracle exists for the specified token.
    error NoOracleExist();

    /// @notice Thrown when the oracle returns a price of zero for a token.
    error InvalidTokenWithPriceOfZero();

    /// @notice Thrown when an array length is invalid or does not match the expected length.
    error InvalidArrayLength();

    // ┏━━━━━━━━━━━━━━━━━━┓
    // ┃     Events       ┃
    // ┗━━━━━━━━━━━━━━━━━━┛

    /// @notice Emitted when a new fee configuration is set for a function selector.
    /// @param selector The function selector.
    /// @param feeType The type of fee applied.
    /// @param feePercentage The fee percentage in basis points.
    event FeeConfigSet(bytes4 indexed selector, FeeType feeType, uint256 feePercentage);

    /// @notice Emitted when a token getter contract is set for a target contract and function selector.
    /// @param target The target contract address.
    /// @param selector The function selector.
    /// @param tokenGetter The address of the token getter contract.
    event TokenGetterSet(address indexed target, bytes4 indexed selector, address tokenGetter);

    /// @notice Emitted when a global fallback token getter is set for a function selector.
    /// @param selector The function selector.
    /// @param tokenGetter The address of the global token getter contract.
    event GlobalTokenGetterSet(bytes4 indexed selector, address tokenGetter);

    /// @notice Emitted when a minimum fee amount in USD is set for a specific fee type.
    /// @param feeType The fee type.
    /// @param minFeeUSD The minimum fee amount in USD (18 decimals).
    event MinFeeSet(FeeType feeType, uint256 minFeeUSD);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃            Admin Functions          ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Sets the fee configuration for a specific function selector.
    /// @param selector Function selector to configure the fee for.
    /// @param feeType Type of fee (Deposit, Withdraw, Reward).
    /// @param feePercentage Fee percentage in basis points (max 10000).
    function setFunctionFeeConfig(bytes4 selector, FeeType feeType, uint256 feePercentage) external;

    /// @notice Sets a token getter contract for a specific target contract and function selector.
    /// @param selector Function selector for which the token getter is set.
    /// @param tokenGetter Address of the token getter contract.
    /// @param target Target contract address where the selector is used.
    function setTokenGetter(bytes4 selector, address tokenGetter, address target) external;

    /// @notice Sets a global fallback token getter contract for a specific function selector.
    /// @param selector Function selector for which the global token getter is set.
    /// @param tokenGetter Address of the token getter contract.
    function setGlobalTokenGetter(bytes4 selector, address tokenGetter) external;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃          View / Utility             ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Retrieves the token address associated with a function call on a target contract.
    /// @dev Uses a specific token getter if available, otherwise falls back to a global one.
    /// @param target Target contract address.
    /// @param selector Function selector of the target function.
    /// @param params Encoded parameters for the token getter to use.
    /// @return token Address of the token used for fee payment.
    /// @return exists Boolean indicating if a token getter was found.
    function getTokenForAction(address target, bytes4 selector, bytes memory params)
        external
        view
        returns (address, bool);

    /// @notice Calculates the applicable fee amount for a given token, function selector, and volume.
    /// @dev Returns the higher of the calculated fee or the configured minimum fee in USD.
    /// @param token Address of the token being charged.
    /// @param selector Function selector for which the fee is being calculated.
    /// @param volume Transaction volume (usually token amount).
    /// @return The applicable fee amount denominated in USD (18 decimals).
    function calculateFee(address token, bytes4 selector, uint256 volume) external view returns (uint256);

    /// @notice Converts a fee denominated in USD to its equivalent token amount.
    /// @param token Address of the token.
    /// @param feeInUSD Fee amount in USD (18 decimals).
    /// @return Equivalent token amount based on the oracle price.
    function calculateTokenAmount(address token, uint256 feeInUSD) external view returns (uint256);

    /// @notice Returns the address of the token getter contract used for a specific target and selector.
    /// @param target Target contract address.
    /// @param selector Function selector.
    /// @return Address of the token getter contract (or zero address if none found).
    function tokenGetter(address target, bytes4 selector) external view returns (address);

    /// @notice Returns the fee configuration for a given function selector.
    /// @param selector Function selector.
    /// @return The FeeConfig struct associated with the selector.
    function functionFeeConfig(bytes4 selector) external view returns (FeeConfig memory);

    /// @notice Returns the maximum allowed fee percentage for a specific FeeType.
    /// @param feeType FeeType enum value.
    /// @return Maximum fee percentage allowed.
    function maxFeeLimit(FeeType feeType) external view returns (uint256);

    /// @notice Returns the minimum fee amount in USD for a specific FeeType.
    /// @param feeType FeeType enum value.
    /// @return Minimum fee in USD (18 decimals).
    function minFeeInUSD(FeeType feeType) external view returns (uint256);

    /// @notice Checks if a given token has an associated price oracle.
    /// @param token Address of the token.
    /// @return Boolean indicating if an oracle exists for the token.
    function hasOracle(address token) external view returns (bool);

    /// @notice Returns the address of the configured price oracle.
    /// @return Address of the oracle contract.
    function priceOracle() external view returns (address);
}
