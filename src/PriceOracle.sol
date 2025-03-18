// SPDX-License-Identifier:MIT
pragma solidity ^0.8.24;

import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";

contract PriceOracle is Ownable, IPriceOracle {
    IPyth private pythOracle;

    mapping(address token => bytes32 oracleID) private oracleIDs;

    constructor(address _pythOracle) {
        pythOracle = IPyth(_pythOracle);
    }

    function setOracleID(address _token, bytes32 _oracleID) external onlyOwner {
        oracleIDs[_token] = _oracleID;

        emit OracleSet(_token, _oracleID);
    }

    function getTokenPrice(address _token) external view returns (uint256) {
        bytes32 _oracleID = oracleIDs[_token];

        if (_oracleID == bytes32(0)) {
            revert OracleNotExist(_token);
        }

        PythStructs.Price memory price = pythOracle.getPriceUnsafe(_oracleID);

        return _scalePythPrice(price.price, price.expo);
    }

    function _scalePythPrice(int256 _price, int32 _expo) internal pure returns (uint256) {
        if (_price < 0) {
            revert NegativePriceNotAllowed();
        }

        uint256 _absExpo = uint32(-_expo);

        if (_expo <= -18) {
            return uint256(_price) * (10 ** (_absExpo - 18));
        }

        return uint256(_price) * 10 ** (18 - _absExpo);
    }

    function oracleID(address _token) external view returns (bytes32) {
        return oracleIDs[_token];
    }
}
