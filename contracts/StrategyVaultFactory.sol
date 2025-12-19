// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {StrategyVault} from "./StrategyVault.sol";
import {IFeeController} from "./interfaces/IFeeController.sol";
import {IFeeHandler} from "./interfaces/IFeeHandler.sol";
import {IActionRegistry} from "./interfaces/IActionRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StrategyVaultFactory
 * @dev Factory for deploying UUPS proxy instances of StrategyVault
 * Gas-efficient: ~30k per vault after first deployment
 */
contract StrategyVaultFactory is Ownable {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       StateVariables      ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Implementation contract (deployed once)
    StrategyVault public implementation;

    /// @notice Fee controller (used for all vaults)
    IFeeController public feeController;

    /// @notice Fee handler (used for all vaults)
    IFeeHandler public feeHandler;

    /// @notice Action registry (used for all vaults)
    IActionRegistry public actionRegistry;

    /// @notice Track all deployed vault proxies
    address[] public deployedVaults;

    /// @notice Map owner to their vaults
    mapping(address => address[]) public userVaults;

    /// @notice Map vault address to its index
    mapping(address => uint256) public vaultIndex;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃         Events            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    event VaultProxyDeployed(
        address indexed proxyAddress, address indexed owner, uint256 vaultIndex, uint256 timestamp
    );

    event ImplementationDeployed(address indexed implementation, uint256 timestamp);

    event ImplementationUpgraded(address indexed newImplementation, uint256 timestamp);

    event ConfigurationUpdated(address feeController, address feeHandler, address actionRegistry);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Custom Errors       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    error InvalidAddress();
    error InvalidConfiguration();
    error ImplementationNotDeployed();

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    constructor(address _feeController, address _feeHandler, address _actionRegistry, address _implementation)
        Ownable(msg.sender)
    {
        _setConfiguration(_feeController, _feeHandler, _actionRegistry);
        _setImplementation(payable(_implementation));
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Deployment Functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Deploy a new vault via proxy
     * @return proxyAddress The address of the new proxy instance
     *
     * @dev Creates a minimal proxy that delegates to the implementation
     * Gas cost: ~30k (vs ~75k for full contract deployment)
     */
    // function deployVault() public returns (address proxyAddress) {
    //     if (address(implementation) == address(0)) {
    //         revert ImplementationNotDeployed();
    //     }

    //     // Create proxy with initialization data
    //     bytes memory initData = abi.encodeCall(
    //         StrategyVault.initialize, (msg.sender, address(feeController), address(feeHandler), address(actionRegistry))
    //     );

    //     // Deploy ERC1967 proxy (UUPS compatible)
    //     ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
    //     proxyAddress = address(proxy);

    //     // Track deployment
    //     deployedVaults.push(proxyAddress);
    //     uint256 index = deployedVaults.length - 1;
    //     vaultIndex[proxyAddress] = index;

    //     // Track user's vaults
    //     userVaults[msg.sender].push(proxyAddress);

    //     emit VaultProxyDeployed(proxyAddress, msg.sender, index, block.timestamp);

    //     return proxyAddress;
    // }
    function deployVaultDeterministic(bytes32 salt) external returns (address proxyAddress) {
        bytes memory initData = abi.encodeCall(
            StrategyVault.initialize, (msg.sender, address(feeController), address(feeHandler), address(actionRegistry))
        );

        ERC1967Proxy proxy = new ERC1967Proxy{salt: salt}(address(implementation), initData);

        proxyAddress = address(proxy);

        deployedVaults.push(proxyAddress);
        vaultIndex[proxyAddress] = deployedVaults.length - 1;
        userVaults[msg.sender].push(proxyAddress);

        emit VaultProxyDeployed(proxyAddress, msg.sender, vaultIndex[proxyAddress], block.timestamp);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Implementation Management    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Deploy or update implementation contract
     * @param _implementation Address of new implementation
     *
     * @dev Called during factory setup or to upgrade all vaults
     * Note: Vaults use UUPS pattern, each can upgrade independently
     */
    function setImplementation(address _implementation) external onlyOwner {
        _setImplementation(payable(_implementation));
    }

    function _setImplementation(address payable _implementation) internal {
        require(_implementation != address(0), "Invalid implementation");

        bool isNew = address(implementation) == address(0);
        implementation = StrategyVault(_implementation);

        if (isNew) {
            emit ImplementationDeployed(_implementation, block.timestamp);
        } else {
            emit ImplementationUpgraded(_implementation, block.timestamp);
        }
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Configuration Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Update factory configuration
     */
    function setConfiguration(address _feeController, address _feeHandler, address _actionRegistry)
        external
        onlyOwner
    {
        _setConfiguration(_feeController, _feeHandler, _actionRegistry);
    }

    function _setConfiguration(address _feeController, address _feeHandler, address _actionRegistry) internal {
        if (_feeController == address(0) || _feeHandler == address(0) || _actionRegistry == address(0)) {
            revert InvalidAddress();
        }

        feeController = IFeeController(_feeController);
        feeHandler = IFeeHandler(_feeHandler);
        actionRegistry = IActionRegistry(_actionRegistry);

        emit ConfigurationUpdated(_feeController, _feeHandler, _actionRegistry);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       View Functions             ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Get total deployed vaults
     */
    function getDeployedVaultsCount() external view returns (uint256) {
        return deployedVaults.length;
    }

    /**
     * @notice Get user's vaults
     */
    function getUserVaults(address user) external view returns (address[] memory) {
        return userVaults[user];
    }

    /**
     * @notice Get user's vault count
     */
    function getUserVaultsCount(address user) external view returns (uint256) {
        return userVaults[user].length;
    }

    /**
     * @notice Get vault at index
     */
    function getVaultAt(uint256 index) external view returns (address) {
        return deployedVaults[index];
    }

    /**
     * @notice Get user's vault at index
     */
    function getUserVaultAt(address user, uint256 index) external view returns (address) {
        return userVaults[user][index];
    }

    /**
     * @notice Check if address is deployed vault
     */
    function isDeployedVault(address vault) external view returns (bool) {
        if (deployedVaults.length == 0) return false;

        uint256 index = vaultIndex[vault];
        return index < deployedVaults.length && deployedVaults[index] == vault;
    }

    /**
     * @notice Get vaults paginated
     */
    function getDeployedVaults(uint256 offset, uint256 limit) external view returns (address[] memory vaults) {
        uint256 total = deployedVaults.length;
        if (offset >= total) return new address[](0);

        uint256 remaining = total - offset;
        uint256 count = limit < remaining ? limit : remaining;

        vaults = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            vaults[i] = deployedVaults[offset + i];
        }

        return vaults;
    }

    /**
     * @notice Get implementation address
     */
    function getImplementation() external view returns (address) {
        return address(implementation);
    }
}
