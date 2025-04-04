// SPDX-License-Identifier:MIT
pragma solidity ^0.8.26;

interface IFeeController {
    enum FeeType {
        Deposit,
        Withdraw,
        Reward
    }

    struct FeeConfig {
        FeeType feeType;
        uint256 feePercentage; // e.g., 100 = 1% (basis points)
    }

    error FeePercentageExceedLimit();
    error ZeroAddressNotValid();
    error NoOracleExist();
    error InvalidTokenWithPriceOfZero();
    error InvalidArrayLength();

    event FeeConfigSet(bytes4 indexed selector, FeeType feeType, uint256 feePercentage);
    event TokenGetterSet(address indexed target, bytes4 indexed selector, address tokenGetter);
    event GlobalTokenGetterSet(bytes4 indexed selector, address tokenGetter);
    event MinFeeSet(FeeType feeType, uint256 minFeeUSD);

    function setFunctionFeeConfig(bytes4 _selector, FeeType _feeType, uint256 _feePercentage) external;

    function getTokenForAction(address _target, bytes4 _selector, bytes memory _params)
        external
        view
        returns (address, bool);
    function calculateFee(address _token, bytes4 _selector, uint256 _volume) external view returns (uint256);
    function calculateTokenAmount(address token, uint256 feeInUSD) external view returns (uint256);
    function functionFeeConfig(bytes4 _selector) external view returns (FeeConfig memory);
    function maxFeeLimit(FeeType _type) external view returns (uint256);
    function minFeeInUSD(FeeType _type) external view returns (uint256);
    function hasOracle(address token) external view returns (bool);
}
