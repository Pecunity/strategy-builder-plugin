// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IFeeManager {
    enum FeeType {
        FixedFee,
        PostCallFee,
        PreCallFee
    }

    struct FeeInfo {
        uint256 value; // Fee in basis points (1% = 100 basis points) or fixed amount when feeType is fixed
        FeeType feeType;
        address calculator;
    }

    function calculateFeeForPreCallAction(bytes4 functionSelector, bytes calldata parameter)
        external
        view
        returns (uint256);
    function calculateFeeForPostCallAction(bytes4 functionSelector, address basisFeeToken, uint256 basisTokenAmount)
        external
        view
        returns (uint256);

    function getFixedFee(bytes4 functionSelector) external view returns (uint256);

    function calculateFee(address basisToken, uint256 amount) external view returns (uint256);

    function prepareForPayment(uint256 feeAmount, address paymentToken) external returns (uint256);

    function calculateFeeInPaymentTokens(address paymentToken, uint256 fee) external view returns (uint256);

    function octoInk() external view returns (address);
    function inkwell() external view returns (address);

    function handleFee(uint256 feeAmount, address executor, address creator, address paymentToken)
        external
        returns (bool);

    function tokenDistributor() external view returns (address);
    function getFeeType(bytes4 functionSelector) external view returns (FeeType);

    function feeSettings(bytes4 functionSelector) external view returns (FeeInfo memory);

    function getBasisFeeToken(bytes4 functionSelector, bytes calldata parameter) external view returns (address);
}
