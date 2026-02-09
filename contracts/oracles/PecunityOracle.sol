// SPDX-License-Identifier:MIT
pragma solidity ^0.8.26;

import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PecunityOracle is Ownable {
    struct StoredPrice {
        int64 price;
        int32 expo;
        uint256 publishTime;
    }

    /// feedId => price data
    mapping(bytes32 => StoredPrice) public prices;

    /// authorized updater
    mapping(address => bool) public isUpdater;

    event PriceUpdated(bytes32 indexed id, int64 price, int32 expo);
    event UpdaterSet(address indexed updater, bool allowed);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Custom Errors      ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    error NotAuthorized();
    error InvalidPrice();
    error NoPriceAvailable();
    error PriceTooOld();

    constructor() Ownable(msg.sender) {}

    modifier onlyUpdater() {
        require(msg.sender == owner() || isUpdater[msg.sender], "Not authorized");
        _;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Updater Control         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function setUpdater(address updater, bool allowed) external onlyOwner {
        isUpdater[updater] = allowed;
        emit UpdaterSet(updater, allowed);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Manual Price Update     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function updatePrice(bytes32 id, int64 newPrice, int32 expo) external onlyUpdater {
        if (newPrice <= 0) {
            revert InvalidPrice();
        }

        prices[id] = StoredPrice({price: newPrice, expo: expo, publishTime: block.timestamp});

        emit PriceUpdated(id, newPrice, expo);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Pyth-Compatible Getter  ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function getPriceNoOlderThan(bytes32 id, uint256 maxAge) external view returns (PythStructs.Price memory) {
        StoredPrice memory data = prices[id];

        if (data.price <= 0) {
            revert NoPriceAvailable();
        }

        if (block.timestamp - data.publishTime > maxAge) {
            revert PriceTooOld();
        }

        return PythStructs.Price({price: data.price, conf: 0, expo: data.expo, publishTime: data.publishTime});
    }
}
