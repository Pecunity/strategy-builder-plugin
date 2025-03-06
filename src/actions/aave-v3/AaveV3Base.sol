// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
// import {IPriceOracleGetter} from "@aave/core-v3/contracts/interfaces/IPriceOracleGetter.sol";
// import {IWETH} from "@aave/core-v3/contracts/misc/interfaces/IWETH.sol";
// import {ERC20PluginLib} from "../lib/ERC20PluginLib.sol";
// import {AaveV3ExecutionLib} from "./lib/AaveV3ExecutionLib.sol";
// import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// error AaveV3Base__ZeroAmountNotValid();
// error AaveV3Base__HealthFactorNotValid();

// contract AaveV3Base {
//     using ERC20PluginLib for address;
//     using AaveV3ExecutionLib for address;

//     // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
//     // ┃       StateVariable       ┃
//     // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

//     uint256 private constant PERCENTAGE_FACTOR = 10000;

//     IPool public immutable pool;
//     IWETH public immutable WETH;
//     IPriceOracleGetter public immutable oracle;

//     // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
//     // ┃       Modifier            ┃
//     // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

//     modifier nonZeroAmount(uint256 amount) {
//         if (amount == 0) {
//             revert AaveV3Base__ZeroAmountNotValid();
//         }
//         _;
//     }

//     modifier noValidHealthFactor(uint256 hFactor) {
//         if (hFactor < 1e18) {
//             revert AaveV3Base__HealthFactorNotValid();
//         }
//         _;
//     }

//     // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
//     // ┃       Constructor         ┃
//     // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

//     constructor(address _aaveV3Pool, address _WETH, address _priceOracle) {}

//     // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
//     // ┃    Execution functions    ┃
//     // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

//     /* ====== Base AAVE V3 Functions ====== */

//     function supply(address asset, uint256 amount) public nonZeroAmount(amount) {
//         msg.sender.approveToken(address(pool), asset, amount);

//         msg.sender.supply(address(pool), asset, amount);
//     }

//     function supplyETH(uint256 amount) public nonZeroAmount(amount) {
//         msg.sender.depositETH(address(WETH), amount);

//         supply(address(WETH), amount);
//     }

//     function withdraw(address asset, uint256 amount) public nonZeroAmount(amount) {}

//     function withdrawETH(uint256 amount) public nonZeroAmount(amount) {}

//     function borrow(address asset, uint256 amount, uint256 interestRateMode) public nonZeroAmount(amount) {}

//     function borrowETH(uint256 amount, uint256 interestRateMode) public nonZeroAmount(amount) {}

//     function repay(address asset, uint256 amount, uint256 interestRateMode) public nonZeroAmount(amount) {}

//     function repayETH(uint256 amount, uint256 interestRateMode) public nonZeroAmount(amount) {}

//     /* ====== Internal Functions ====== */

//     function _calculateBorrowAmount(address wallet, address asset, uint256 percentage)
//         internal
//         view
//         returns (uint256)
//     {
//         (,, uint256 availableBorrowsBase,,,) = pool.getUserAccountData(wallet);

//         uint256 price = oracle.getAssetPrice(asset);
//         uint256 baseCurrencyDecimals = oracle.BASE_CURRENCY_UNIT();
//         uint256 decimals = IERC20Metadata(asset).decimals();

//         uint256 maxBorrowAmount = availableBorrowsBase * baseCurrencyDecimals / price;
//         return (maxBorrowAmount * 10 ** decimals / baseCurrencyDecimals) * percentage / PERCENTAGE_FACTOR;
//     }

//     function _calculateAdditionalCollateral(address wallet, address asset, uint256 targetHealthFactor)
//         internal
//         view
//         returns (uint256)
//     {
//         (uint256 currentCol, uint256 currentDebt,, uint256 currentLT,,) = pool.getUserAccountData(wallet);

//         uint256 targetCollateral = (targetHealthFactor * currentDebt / 1e18) * PERCENTAGE_FACTOR / currentLT;

//         if (targetCollateral < currentCol) {
//             return 0;
//         }

//         uint256 additionalCollateral = targetCollateral - currentCol;

//         uint256 assetPrice = oracle.getAssetPrice(asset);
//         uint256 decimals = IERC20Metadata(asset).decimals();

//         return assetPrice > 0 ? (additionalCollateral * 10 ** decimals) / assetPrice : 0;
//     }
// }
