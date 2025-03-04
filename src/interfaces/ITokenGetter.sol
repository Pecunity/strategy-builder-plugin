// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

interface ITokenGetter {
    function getTokenForSelector(bytes4 selector, bytes memory params) external view returns (address);
}
