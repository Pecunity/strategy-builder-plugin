// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

interface IPriceOracle {
    error OracleNotExist(address token);
    error NegativePriceNotAllowed();

    event OracleSet(address indexed token, bytes32 oracleID);

    function setOracleID(address _token, bytes32 _oracleID) external;
    function oracleID(address _token) external view returns (bytes32);
    function getTokenPrice(address _token) external view returns (uint256);
}
