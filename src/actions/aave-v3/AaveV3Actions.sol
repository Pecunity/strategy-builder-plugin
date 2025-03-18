// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IAaveOracle} from "@aave/core-v3/contracts/interfaces/IAaveOracle.sol";
import {IWETH} from "@aave/core-v3/contracts/misc/interfaces/IWETH.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAaveV3Actions} from "./interfaces/IAaveV3Actions.sol";

// https://github.com/bgd-labs/aave-address-book/blob/main/src/AaveV3Base.sol

contract AaveV3Actions is IAaveV3Actions {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       StateVariable       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    uint256 public constant PERCENTAGE_FACTOR = 10000;

    address public immutable pool;
    address public immutable WETH;
    IAaveOracle public immutable oracle;

    mapping(bytes4 => uint8) public tokenGetterIDs;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Modifier            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) {
            revert ZeroAmountNotValid();
        }
        _;
    }

    modifier noValidHealthFactor(uint256 hFactor) {
        if (hFactor < 1e18) {
            revert HealthFactorNotValid();
        }
        _;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    constructor(address _aaveV3Pool, address _WETH, address _priceOracle) {
        pool = (_aaveV3Pool);
        WETH = (_WETH);
        oracle = IAaveOracle(_priceOracle);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /* ====== Base AAVE V3 Functions ====== */

    function supply(address wallet, address asset, uint256 amount)
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _approveToken(asset, amount);

        executions[1] = _supply(wallet, asset, amount);

        return executions;
    }

    function supplyETH(address wallet, uint256 amount)
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](3);

        executions[0] = _depositToWETH(amount);

        executions[1] = _approveToken(WETH, amount);

        executions[2] = _supply(wallet, WETH, amount);

        return executions;
    }

    function withdraw(address wallet, address asset, uint256 amount)
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](1);

        executions[0] = _withdraw(wallet, asset, amount);

        return executions;
    }

    function withdrawETH(address wallet, uint256 amount)
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _withdraw(wallet, WETH, amount);
        executions[1] = _withdrawFromWETH(amount);

        return executions;
    }

    function borrow(address wallet, address asset, uint256 amount, uint256 interestRateMode)
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](1);

        executions[0] = _borrow(wallet, asset, amount, interestRateMode);

        return executions;
    }

    function borrowETH(address wallet, uint256 amount, uint256 interestRateMode)
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _borrow(wallet, WETH, amount, interestRateMode);

        executions[1] = _withdrawFromWETH(amount);

        return executions;
    }

    function repay(address wallet, address asset, uint256 amount, uint256 interestRateMode)
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](2);

        executions[0] = _approveToken(asset, amount);

        executions[1] = _repay(wallet, asset, amount, interestRateMode);

        return executions;
    }

    function repayETH(address wallet, uint256 amount, uint256 interestRateMode)
        public
        view
        nonZeroAmount(amount)
        returns (PluginExecution[] memory)
    {
        PluginExecution[] memory executions = new PluginExecution[](3);

        executions[0] = _depositToWETH(amount);

        executions[1] = _approveToken(WETH, amount);

        executions[2] = _repay(wallet, WETH, amount, interestRateMode);

        return executions;
    }

    /* ====== Special AAVE V3 Functions ====== */

    function supplyPercentageOfBalance(address wallet, address asset, uint256 percentage)
        public
        view
        nonZeroAmount(percentage)
        returns (PluginExecution[] memory)
    {
        uint256 supplyAmount = _calculatePercentageAmountOfAssetBalance(wallet, asset, percentage, false);

        return supply(wallet, asset, supplyAmount);
    }

    function supplyPercentageOfBalanceETH(address wallet, uint256 percentage)
        public
        view
        nonZeroAmount(percentage)
        returns (PluginExecution[] memory)
    {
        uint256 supplyAmount = _calculatePercentageAmountOfAssetBalance(wallet, WETH, percentage, true);

        return supplyETH(wallet, supplyAmount);
    }

    function changeSupplyToHealthFactorETH(address wallet, uint256 targetHealthFactor)
        public
        view
        returns (PluginExecution[] memory)
    {
        _validateHealtfactor(targetHealthFactor);
        (uint256 deltaAmount, bool isWithdraw) = _calculateDeltaCol(wallet, WETH, targetHealthFactor);

        if (isWithdraw) {
            return withdrawETH(wallet, deltaAmount);
        } else {
            return supplyETH(wallet, deltaAmount);
        }
    }

    function changeSupplyToHealthFactor(address wallet, address asset, uint256 targetHealthFactor)
        public
        view
        returns (PluginExecution[] memory)
    {
        _validateHealtfactor(targetHealthFactor);
        (uint256 deltaAmount, bool isWithdraw) = _calculateDeltaCol(wallet, asset, targetHealthFactor);

        if (isWithdraw) {
            return withdraw(wallet, asset, deltaAmount);
        } else {
            return supply(wallet, asset, deltaAmount);
        }
    }

    function borrowPercentageOfAvailable(address wallet, address asset, uint256 percentage, uint256 interestRateMode)
        public
        view
        nonZeroAmount(percentage)
        returns (PluginExecution[] memory)
    {
        uint256 borowAmount = _calculateBorrowAmount(wallet, asset, percentage);

        return borrow(wallet, asset, borowAmount, interestRateMode);
    }

    function borrowPercentageOfAvailableETH(address wallet, uint256 percentage, uint256 interestRateMode)
        public
        view
        nonZeroAmount(percentage)
        returns (PluginExecution[] memory)
    {
        uint256 borowAmount = _calculateBorrowAmount(wallet, WETH, percentage);

        return borrowETH(wallet, borowAmount, interestRateMode);
    }

    function changeDebtToHealthFactor() public view {}

    function changeDebtToHealthFactorETH() public view {}
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Internal functions     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _approveToken(address token, uint256 amount) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(IERC20.approve, (address(pool), amount));

        return PluginExecution({target: token, value: 0, data: _data});
    }

    function _repay(address wallet, address asset, uint256 amount, uint256 interestRateMode)
        internal
        view
        returns (PluginExecution memory)
    {
        bytes memory _data = abi.encodeCall(IPool.repay, (asset, amount, interestRateMode, wallet));

        return PluginExecution({target: pool, value: 0, data: _data});
    }

    function _borrow(address wallet, address asset, uint256 amount, uint256 interestRateMode)
        internal
        view
        returns (PluginExecution memory)
    {
        bytes memory _data = abi.encodeCall(IPool.borrow, (asset, amount, interestRateMode, 0, wallet));

        return PluginExecution({target: pool, value: 0, data: _data});
    }

    function _supply(address wallet, address asset, uint256 amount) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(IPool.supply, (asset, amount, wallet, 0));

        return PluginExecution({target: (pool), value: 0, data: _data});
    }

    function _withdraw(address wallet, address asset, uint256 amount) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(IPool.withdraw, (asset, amount, wallet));

        return PluginExecution({target: (pool), value: 0, data: _data});
    }

    function _withdrawFromWETH(uint256 amount) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(IWETH.withdraw, (amount));
        return PluginExecution({target: WETH, value: 0, data: _data});
    }

    function _depositToWETH(uint256 amount) internal view returns (PluginExecution memory) {
        bytes memory _data = abi.encodeCall(IWETH.deposit, ());
        return PluginExecution({target: WETH, value: amount, data: _data});
    }

    function _calculateBorrowAmount(address wallet, address asset, uint256 percentage)
        internal
        view
        returns (uint256)
    {
        (,, uint256 availableBorrowsBase,,,) = IPool(pool).getUserAccountData(wallet);

        uint256 price = oracle.getAssetPrice(asset);
        uint256 decimals = IERC20Metadata(asset).decimals();

        uint256 maxBorrowAmount = availableBorrowsBase * 10 ** decimals / price;
        return (maxBorrowAmount) * percentage / PERCENTAGE_FACTOR;
    }

    function _calculateDeltaCol(address wallet, address asset, uint256 targetHealthFactor)
        internal
        view
        returns (uint256 deltaCol, bool isWithdraw)
    {
        (uint256 currentCol, uint256 currentDebt,, uint256 currentLT,,) = IPool(pool).getUserAccountData(wallet);

        uint256 targetCollateral = (targetHealthFactor * currentDebt / 1e18) * PERCENTAGE_FACTOR / currentLT;

        uint256 deltaColInBaseCurrency;
        if (targetCollateral < currentCol) {
            isWithdraw = true;
            deltaColInBaseCurrency = currentCol - targetCollateral;
        } else {
            deltaColInBaseCurrency = targetCollateral - currentCol;
        }

        uint256 assetPrice = oracle.getAssetPrice(asset);
        uint256 decimals = IERC20Metadata(asset).decimals();

        deltaCol = assetPrice > 0 ? (deltaColInBaseCurrency * 10 ** decimals) / assetPrice : 0;
    }

    function _calculatePercentageAmountOfAssetBalance(address wallet, address asset, uint256 percentage, bool native)
        internal
        view
        returns (uint256)
    {
        uint256 totalBalance = native ? wallet.balance : IERC20(asset).balanceOf(wallet);

        return (totalBalance * percentage) / PERCENTAGE_FACTOR;
    }

    function _validateHealtfactor(uint256 healthFactor) internal pure {
        if (healthFactor < 1e18) {
            revert HealthFactorNotValid();
        }
    }
}
