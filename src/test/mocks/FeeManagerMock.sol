// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IFeeManager} from "../../interfaces/IFeeManager.sol";

contract FeeManagerMock is IFeeManager {
    function calculateFeeForPreCallAction(bytes4 functionSelector, bytes calldata parameter)
        external
        view
        returns (uint256)
    {
        return 0;
    }

    function calculateFeeForPostCallAction(bytes4 functionSelector, address basisFeeToken, uint256 basisTokenAmount)
        external
        view
        returns (uint256)
    {
        return 0;
    }

    function getFixedFee(bytes4 functionSelector) external view returns (uint256) {
        return 0;
    }

    function calculateFee(address basisToken, uint256 amount) external view returns (uint256) {
        return 0;
    }

    function prepareForPayment(uint256 feeAmount, address paymentToken) external returns (uint256) {
        return 0;
    }

    function calculateFeeInPaymentTokens(address paymentToken, uint256 fee) external view returns (uint256) {
        return 0;
    }

    function octoInk() external view returns (address) {
        return address(0);
    }

    function inkwell() external view returns (address) {
        return address(0);
    }

    function handleFee(uint256 feeAmount, address executor, address creator, address paymentToken)
        external
        returns (bool)
    {
        return true;
    }

    function tokenDistributor() external view returns (address) {
        return address(0);
    }

    function getFeeType(bytes4 functionSelector) external view returns (FeeType) {
        return FeeType.FixedFee;
    }

    function feeSettings(bytes4 functionSelector) external view returns (FeeInfo memory) {
        return FeeInfo({value: 0, feeType: FeeType.FixedFee, calculator: address(0)});
    }

    function getBasisFeeToken(bytes4 functionSelector, bytes calldata parameter) external view returns (address) {
        return address(0);
    }
}
