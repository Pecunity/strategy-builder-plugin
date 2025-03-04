// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {IFeeController} from "./interfaces/IFeeController.sol";
import {ITokenGetter} from "./interfaces/ITokenGetter.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";

contract FeeController is IFeeController {
    uint256 public constant PERCENTAGE_DIVISOR = 10000;

    IPriceOracle private oracle;

    // Mapping: function selector => FeeConfig
    mapping(bytes4 => FeeConfig) private functionFeeConfigs;
    // Mapping: target contract => function selector => token getter contract (specific)
    mapping(address => mapping(bytes4 => address)) private tokenGetters;
    // Mapping: function selector => token getter contract (global fallback)
    mapping(bytes4 => address) private globalTokenGetters;
    // Mapping: FeeType => Maximum allowed fee percentage
    mapping(FeeType => uint256) private maxFeeLimits;
    // Mapping: FeeType => Minimum fee in USD (18 decimals)
    mapping(FeeType => uint256) private minFeesInUSD;

    constructor(address _oracle) {
        if (_oracle == address(0)) {
            revert ZeroAddressNotValid();
        }

        oracle = IPriceOracle(_oracle);

        // Default max fees (basis points)
        maxFeeLimits[FeeType.Deposit] = 500; // Max 5%
        maxFeeLimits[FeeType.Withdraw] = 1000; // Max 10%
        maxFeeLimits[FeeType.Reward] = 200; // Max 2%

        // Default min fees in USD (18 decimals, e.g., 1e18 = $1)
        minFeesInUSD[FeeType.Deposit] = 1e18; // $1
        minFeesInUSD[FeeType.Withdraw] = 2e18; // $2
        minFeesInUSD[FeeType.Reward] = 0.5e18; // $0.50
    }

    function setFunctionFeeConfig(bytes4 _selector, FeeType _feeType, uint256 _feePercentage) external {
        if (_feePercentage > maxFeeLimits[_feeType]) {
            revert FeePercentageExceedLimit();
        }

        functionFeeConfigs[_selector] = FeeConfig(_feeType, _feePercentage);

        emit FeeConfigSet(_selector, _feeType, _feePercentage);
    }

    function setTokenGetter(bytes4 _selector, address _tokenGetter, address _target) external {
        if (_target == address(0) || _tokenGetter == address(0)) {
            revert ZeroAddressNotValid();
        }

        tokenGetters[_target][_selector] = _tokenGetter;
        emit TokenGetterSet(_target, _selector, _tokenGetter);
    }

    function setGlobalTokenGetter(bytes4 _selector, address _tokenGetter) external {
        if (_tokenGetter == address(0)) {
            revert ZeroAddressNotValid();
        }

        globalTokenGetters[_selector] = _tokenGetter;
        emit GlobalTokenGetterSet(_selector, _tokenGetter);
    }

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

    function calculateTokenAmount(address token, uint256 feeInUSD) external view returns (uint256) {
        bytes32 oracleID = oracle.oracleID(token);

        if (oracleID == bytes32(0)) {
            revert NoOracleExist();
        }

        uint256 tokenPrice = oracle.getTokenPrice(token);

        return feeInUSD * 10 ** 18 / tokenPrice;
    }

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

    function tokenGetter(address _target, bytes4 _selector) public view returns (address) {
        address _tokenGetter = tokenGetters[_target][_selector];

        if (_tokenGetter == address(0)) {
            _tokenGetter = globalTokenGetters[_selector];
        }

        return _tokenGetter;
    }

    function functionFeeConfig(bytes4 _selector) external view returns (FeeConfig memory) {
        return functionFeeConfigs[_selector];
    }

    function maxFeeLimit(FeeType _type) external view returns (uint256) {
        return maxFeeLimits[_type];
    }

    function minFeeInUSD(FeeType _type) external view returns (uint256) {
        return minFeesInUSD[_type];
    }

    function priceOracle() external view returns (address) {
        return address(oracle);
    }

    function hasOracle(address token) external view returns (bool) {
        return oracle.oracleID(token) != bytes32(0);
    }
}
