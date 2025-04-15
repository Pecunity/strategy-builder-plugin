// SPDX-License-Identifier:MIT
pragma solidity ^0.8.26;

import {IFeeController} from "./interfaces/IFeeController.sol";
import {ITokenGetter} from "./interfaces/ITokenGetter.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title FeeController
/// @notice Manages fee configurations and calculations for various function selectors and fee types.
/// @dev Supports minimum fee enforcement in USD, maximum fee limits, dynamic token price fetching via oracle,
///      and token resolution for fee payments using specific or global token getter contracts.
contract FeeController is Ownable, IFeeController {
    /// @notice Precision constant for fee percentage calculations (basis points - 100% = 10000).
    uint256 public constant PERCENTAGE_DIVISOR = 10000;

    // ┏━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   State Variables    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice The price oracle used for fetching token prices and verifying supported tokens.
    IPriceOracle private oracle;

    /// @notice Maps function selector to its fee configuration.
    mapping(bytes4 => FeeConfig) private functionFeeConfigs;

    /// @notice Maps target contract address and function selector to a token getter contract (specific).
    mapping(address => mapping(bytes4 => address)) private tokenGetters;

    /// @notice Maps function selector to a fallback token getter contract (global).
    mapping(bytes4 => address) private globalTokenGetters;

    /// @notice Maps FeeType to its maximum allowed fee percentage.
    mapping(FeeType => uint256) private maxFeeLimits;

    /// @notice Maps FeeType to its minimum fee amount in USD (18 decimals).
    mapping(FeeType => uint256) private minFeesInUSD;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃              Constructor            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Initializes the FeeController contract.
    /// @param _oracle Address of the price oracle contract.
    /// @param _maxFeeLimits Array of maximum fee percentages for Deposit, Withdraw, and Reward types.
    /// @param _minFeesInUSD Array of minimum fee amounts in USD for Deposit, Withdraw, and Reward types.
    constructor(address _oracle, uint256[] memory _maxFeeLimits, uint256[] memory _minFeesInUSD) {
        if (_oracle == address(0)) {
            revert ZeroAddressNotValid();
        }

        if (_maxFeeLimits.length != 3 || _minFeesInUSD.length != 3) {
            revert InvalidArrayLength();
        }

        oracle = IPriceOracle(_oracle);

        // Default max fees (basis points)
        maxFeeLimits[FeeType.Deposit] = _maxFeeLimits[0];
        maxFeeLimits[FeeType.Withdraw] = _maxFeeLimits[1];
        maxFeeLimits[FeeType.Reward] = _maxFeeLimits[2];

        // Default min fees in USD (18 decimals, e.g., 1e18 = $1)
        minFeesInUSD[FeeType.Deposit] = _minFeesInUSD[0]; // $1
        minFeesInUSD[FeeType.Withdraw] = _minFeesInUSD[1]; // $2
        minFeesInUSD[FeeType.Reward] = _minFeesInUSD[2]; // $0.50
    }

    /// @inheritdoc IFeeController
    function setFunctionFeeConfig(bytes4 _selector, FeeType _feeType, uint256 _feePercentage) external {
        if (_feePercentage > maxFeeLimits[_feeType]) {
            revert FeePercentageExceedLimit();
        }

        functionFeeConfigs[_selector] = FeeConfig(_feeType, _feePercentage);

        emit FeeConfigSet(_selector, _feeType, _feePercentage);
    }

    /// @inheritdoc IFeeController
    function setTokenGetter(bytes4 _selector, address _tokenGetter, address _target) external {
        if (_target == address(0) || _tokenGetter == address(0)) {
            revert ZeroAddressNotValid();
        }

        tokenGetters[_target][_selector] = _tokenGetter;
        emit TokenGetterSet(_target, _selector, _tokenGetter);
    }

    /// @inheritdoc IFeeController
    function setGlobalTokenGetter(bytes4 _selector, address _tokenGetter) external {
        if (_tokenGetter == address(0)) {
            revert ZeroAddressNotValid();
        }

        globalTokenGetters[_selector] = _tokenGetter;
        emit GlobalTokenGetterSet(_selector, _tokenGetter);
    }

    /// @inheritdoc IFeeController
    function calculateFee(address _token, bytes4 _selector, uint256 _volume) external view returns (uint256) {
        bytes32 _oracleID = oracle.oracleID(_token);
        FeeConfig memory _config = functionFeeConfigs[_selector];

        uint256 _minFeeInUSD = minFeesInUSD[_config.feeType];

        if (_oracleID == bytes32(0) || _config.feePercentage == 0) {
            return _minFeeInUSD;
        }

        uint256 _tokenPrice = oracle.getTokenPrice(_token);

        uint256 _feeAmount = _volume * _config.feePercentage / PERCENTAGE_DIVISOR;
        uint256 _feeInUSD = _feeAmount * _tokenPrice / 10 ** 18;

        return _feeInUSD < _minFeeInUSD ? _minFeeInUSD : _feeInUSD;
    }

    /// @inheritdoc IFeeController
    function calculateTokenAmount(address token, uint256 feeInUSD) external view returns (uint256) {
        bytes32 oracleID = oracle.oracleID(token);

        if (oracleID == bytes32(0)) {
            revert NoOracleExist();
        }

        uint256 tokenPrice = oracle.getTokenPrice(token);

        if (tokenPrice == 0) {
            revert InvalidTokenWithPriceOfZero();
        }

        return feeInUSD * 10 ** 18 / tokenPrice;
    }

    /// @inheritdoc IFeeController
    function getTokenForAction(address _target, bytes4 _selector, bytes memory _params)
        external
        view
        returns (address, bool)
    {
        address _tokenGetter = tokenGetter(_target, _selector);

        if (_tokenGetter == address(0)) {
            return (address(0), false);
        }

        address _token = ITokenGetter(_tokenGetter).getTokenForSelector(_selector, _params);

        return (_token, true);
    }

    /// @inheritdoc IFeeController
    function tokenGetter(address _target, bytes4 _selector) public view returns (address) {
        address _tokenGetter = tokenGetters[_target][_selector];

        if (_tokenGetter == address(0)) {
            _tokenGetter = globalTokenGetters[_selector];
        }

        return _tokenGetter;
    }

    /// @inheritdoc IFeeController
    function functionFeeConfig(bytes4 _selector) external view returns (FeeConfig memory) {
        return functionFeeConfigs[_selector];
    }

    /// @inheritdoc IFeeController
    function maxFeeLimit(FeeType _type) external view returns (uint256) {
        return maxFeeLimits[_type];
    }

    /// @inheritdoc IFeeController
    function minFeeInUSD(FeeType _type) external view returns (uint256) {
        return minFeesInUSD[_type];
    }

    /// @inheritdoc IFeeController
    function priceOracle() external view returns (address) {
        return address(oracle);
    }

    /// @inheritdoc IFeeController
    function hasOracle(address token) external view returns (bool) {
        return oracle.oracleID(token) != bytes32(0);
    }
}
