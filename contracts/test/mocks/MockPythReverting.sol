// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract MockPythReverting {
    function getPriceNoOlderThan(bytes32, uint64) external pure returns (PythStructs.Price memory) {
        revert("Mocked revert: stale price");
    }
}
