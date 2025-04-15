// SPDX-License-Identifier:MIT
pragma solidity ^0.8.26;

import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";

contract PriceOracle is Ownable, IPriceOracle {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       StateVariable       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Address of the Pyth Oracle contract used for fetching price data.
    /// @dev Immutable after deployment.
    IPyth private immutable pythOracle;

    /// @notice Mapping of allowed payment tokens to their corresponding Pyth Oracle price feed IDs.
    /// @dev Used to resolve the oracle price feed for a specific token.
    mapping(address token => bytes32 oracleID) private oracleIDs;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Deploys the contract and sets the Pyth Oracle and contract owner.
    /// @dev Initializes the oracle contract and transfers ownership to the given owner address.
    /// @param _pythOracle Address of the deployed Pyth Oracle contract.
    constructor(address _pythOracle) {
        pythOracle = IPyth(_pythOracle);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃     Public Functions      ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc IPriceOracle
    function setOracleID(address _token, bytes32 _oracleID) external onlyOwner {
        oracleIDs[_token] = _oracleID;

        emit OracleSet(_token, _oracleID);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Internal Functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━┛

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

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       View Functions     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc IPriceOracle
    function getTokenPrice(address _token) external view returns (uint256) {
        bytes32 _oracleID = oracleIDs[_token];

        if (_oracleID == bytes32(0)) {
            revert OracleNotExist(_token);
        }

        PythStructs.Price memory price = pythOracle.getPriceUnsafe(_oracleID);

        return _scalePythPrice(price.price, price.expo);
    }

    /// @inheritdoc IPriceOracle
    function oracleID(address _token) external view returns (bytes32) {
        return oracleIDs[_token];
    }
}
