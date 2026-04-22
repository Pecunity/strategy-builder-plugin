// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFeeHandler} from "../../interfaces/IFeeHandler.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @title MockVault
/// @notice Mock vault contract for testing FeeHandler.handleFeeWithVault.
/// @dev The FeeHandler calls owner() on msg.sender to determine the fee payer.
///      This contract must be registered as a deployed vault in the StrategyVaultFactory.
contract MockVault {
    using SafeTransferLib for address;

    address private _owner;

    constructor(address owner_) {
        _owner = owner_;
    }

    /// @notice Returns the configured owner — called by FeeHandler.handleFeeWithVault.
    function owner() external view returns (address) {
        return _owner;
    }

    /// @notice Sets a new owner address.
    function setOwner(address newOwner) external {
        _owner = newOwner;
    }

    /// @notice Calls handleFeeWithVault on the given FeeHandler.
    /// @param feeHandler Address of the FeeHandler contract.
    /// @param token ERC20 token used for the fee.
    /// @param amount Total fee amount.
    /// @param beneficiary Address receiving the beneficiary share.
    /// @param creator Optional creator address (use address(0) if none).
    /// @return totalAmount Total fee + burn amount recorded by the FeeHandler.
    function callHandleFeeWithVault(
        address feeHandler,
        address token,
        uint256 amount,
        address beneficiary,
        address creator
    ) external returns (uint256 totalAmount) {
        IERC20(token).approve(feeHandler, amount);
        totalAmount = IFeeHandler(feeHandler).handleFeeWithVault(token, amount, beneficiary, creator);
    }

    /// @notice Calls handleFeeWithVaultETH on the given FeeHandler.
    /// @param feeHandler Address of the FeeHandler contract.
    /// @param amount Total fee amount (in ETH).
    /// @param beneficiary Address receiving the beneficiary share.
    /// @param creator Optional creator address (use address(0) if none).
    /// @return totalAmount Total fee + burn amount recorded by the FeeHandler.
    function callHandleFeeWithVaultETH(address feeHandler, uint256 amount, address beneficiary, address creator)
        external
        payable
        returns (uint256 totalAmount)
    {
        totalAmount = IFeeHandler(feeHandler).handleFeeWithVaultETH{value: msg.value}(amount, beneficiary, creator);
    }

    receive() external payable {}
}
