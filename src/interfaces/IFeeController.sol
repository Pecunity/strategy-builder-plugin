// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

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

    event FeeConfigSet(bytes4 indexed selector, FeeType feeType, uint256 feePercentage);
    event TokenGetterSet(address indexed target, bytes4 indexed selector, address tokenGetter);
    event GlobalTokenGetterSet(bytes4 indexed selector, address tokenGetter);
    event MinFeeSet(FeeType feeType, uint256 minFeeUSD);

    function setFunctionFeeConfig(bytes4 _selector, FeeType _feeType, uint256 _feePercentage) external;

    function functionFeeConfig(bytes4 _selector) external view returns (FeeConfig memory);
    function maxFeeLimit(FeeType _type) external view returns (uint256);
    function minFeeInUSD(FeeType _type) external view returns (uint256);
}
