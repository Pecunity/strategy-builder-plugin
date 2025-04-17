// SPDX-License-Identifier:MIT
pragma solidity ^0.8.28;

import {BasePlugin} from "modular-account-libs/plugins/BasePlugin.sol";
import {IPluginExecutor} from "modular-account-libs/interfaces/IPluginExecutor.sol";
import {
    ManifestFunction,
    ManifestAssociatedFunctionType,
    ManifestAssociatedFunction,
    PluginManifest,
    PluginMetadata,
    IPlugin
} from "modular-account-libs/interfaces/IPlugin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStrategyBuilderPlugin} from "./interfaces/IStrategyBuilderPlugin.sol";
import {ICondition} from "./interfaces/ICondition.sol";
import {IFeeController} from "./interfaces/IFeeController.sol";
import {IFeeHandler} from "./interfaces/IFeeHandler.sol";
import {IAction} from "./interfaces/IAction.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title StrategyBuilderPlugin
 * @dev A plugin for creating, executing, and managing automated strategies based on predefined conditions and actions.
 */
contract StrategyBuilderPlugin is BasePlugin, ReentrancyGuard, IStrategyBuilderPlugin {
    using Address for address;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       StateVariable       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    // metadata used by the pluginMetadata() method down below
    string public constant NAME = "Strategy Builder Plugin";
    string public constant VERSION = "1.0.0";
    string public constant AUTHOR = "3Blocks";

    // this is a constant used in the manifest, to reference our only dependency: the single owner plugin
    // since it is the first, and only, plugin the index 0 will reference the single owner plugin
    // we can use this to tell the modular account that we should use the single owner plugin to validate our user op
    // in other words, we'll say "make sure the person calling increment is an owner of the account using our single plugin"
    uint256 internal constant _MANIFEST_DEPENDENCY_INDEX_OWNER_USER_OP_VALIDATION = 0;

    /// @notice Fee controller contract
    IFeeController public immutable feeController;
    /// @notice Fee handler contract
    IFeeHandler public immutable feeHandler;

    /// @notice Maps strategy IDs to strategy data
    mapping(bytes32 => Strategy) private strategies;
    /// @notice Tracks where each strategy is used
    mapping(bytes32 => uint32[]) private strategiesUsed;
    /// @notice Maps automation IDs to their index in the owner's strategy usage array
    mapping(bytes32 => uint32) private automationsToIndex; //Maps each automation ID to its index in the owner's used strategy array.
    /// @notice Maps automation IDs to automation data
    mapping(bytes32 => Automation) private automations;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Modifier            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    modifier strategyExist(address wallet, uint32 id) {
        if (strategies[getStorageId(wallet, id)].steps.length == 0) {
            revert StrategyDoesNotExist();
        }
        _;
    }

    modifier strategyDoesNotExist(address wallet, uint32 id) {
        if (strategies[getStorageId(wallet, id)].steps.length > 0) {
            revert StrategyAlreadyExist();
        }
        _;
    }

    modifier automationExist(address wallet, uint32 id) {
        if (automations[getStorageId(wallet, id)].condition.conditionAddress == address(0)) {
            revert AutomationNotExist();
        }
        _;
    }

    modifier automationDoesNotExist(address wallet, uint32 id) {
        if (automations[getStorageId(wallet, id)].condition.conditionAddress != address(0)) {
            revert AutomationAlreadyExist();
        }
        _;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Deploys the StrategyBuilder contract with the given fee controller and fee handler.
    /// @dev Sets the addresses for fee management contracts.
    /// @param _feeController Address of the contract responsible for fee configuration and validation.
    /// @param _feeHandler Address of the contract responsible for fee distribution and handling.
    constructor(address _feeController, address _feeHandler) {
        feeController = IFeeController(_feeController);
        feeHandler = IFeeHandler(_feeHandler);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc IStrategyBuilderPlugin
    function createStrategy(uint32 id, address creator, StrategyStep[] calldata steps)
        external
        strategyDoesNotExist(msg.sender, id)
    {
        _validateSteps(steps);

        Strategy storage newStrategy = strategies[getStorageId(msg.sender, id)];

        newStrategy.creator = creator;

        for (uint256 i = 0; i < steps.length; i++) {
            StrategyStep memory step = steps[i];

            if (step.condition.conditionAddress != address(0)) {
                // Validate the condition
                _validateCondition(step.condition);

                _changeStrategyInCondition(msg.sender, step.condition.conditionAddress, step.condition.id, id, true);
            }

            // Create a new step in storage
            StrategyStep storage newStep = newStrategy.steps.push();
            newStep.condition = step.condition;

            // Loop through the actions and add them to the step
            for (uint256 j = 0; j < step.actions.length; j++) {
                _validateAction(step.actions[j]);
                newStep.actions.push(step.actions[j]);
            }
        }

        emit StrategyCreated(msg.sender, id, creator, newStrategy);
    }

    /// @inheritdoc IStrategyBuilderPlugin
    function deleteStrategy(uint32 id) external strategyExist(msg.sender, id) {
        bytes32 storageId = getStorageId(msg.sender, id);

        if (strategiesUsed[storageId].length > 0) {
            revert StrategyIsInUse();
        }

        Strategy memory _strategy = strategies[storageId];

        for (uint256 i = 0; i < _strategy.steps.length; i++) {
            Condition memory condition = _strategy.steps[i].condition;
            if (condition.conditionAddress != address(0)) {
                _changeStrategyInCondition(msg.sender, condition.conditionAddress, condition.id, id, false);
            }
        }

        delete strategies[storageId];

        emit StrategyDeleted(msg.sender, id);
    }

    /// @inheritdoc IStrategyBuilderPlugin
    function executeStrategy(uint32 id) external strategyExist(msg.sender, id) nonReentrant {
        _executeStrategy(msg.sender, id);
    }

    /// @inheritdoc IStrategyBuilderPlugin
    function createAutomation(
        uint32 id,
        uint32 strategyId,
        address paymentToken,
        uint256 maxFeeInUSD,
        Condition calldata condition
    ) external automationDoesNotExist(msg.sender, id) strategyExist(msg.sender, strategyId) {
        //Specific validations
        _validatePaymentToken(paymentToken);

        _validateCondition(condition);

        _changeAutomationInCondition(msg.sender, condition.conditionAddress, condition.id, id, true);

        bytes32 automationSID = getStorageId(msg.sender, id);
        Automation storage _newAutomation = automations[getStorageId(msg.sender, id)];

        _newAutomation.condition = condition;
        _newAutomation.strategyId = strategyId;

        _newAutomation.paymentToken = paymentToken;
        _newAutomation.maxFeeAmount = maxFeeInUSD;

        bytes32 strategySID = getStorageId(msg.sender, strategyId);
        strategiesUsed[strategySID].push(id);
        automationsToIndex[automationSID] = uint32(strategiesUsed[strategySID].length - 1);

        emit AutomationCreated(msg.sender, id, strategyId, condition, paymentToken, maxFeeInUSD);
    }

    /// @inheritdoc IStrategyBuilderPlugin
    function deleteAutomation(uint32 id) external automationExist(msg.sender, id) {
        _deleteAutomation(msg.sender, id);
    }

    /// @inheritdoc IStrategyBuilderPlugin
    function executeAutomation(uint32 id, address wallet, address beneficary)
        external
        automationExist(wallet, id)
        nonReentrant
    {
        bytes32 automationSID = getStorageId(wallet, id);
        Automation memory _automation = automations[automationSID];

        //Check the condition
        (uint8 conditionResult,) = _checkCondition(wallet, _automation.condition);

        if (conditionResult == 0) {
            revert AutomationNotExecutable(_automation.condition.conditionAddress, _automation.condition.id);
        }

        uint256 feeInUSD = _executeStrategy(wallet, _automation.strategyId);

        if (feeInUSD > _automation.maxFeeAmount) {
            revert FeeExceedMaxFee();
        }

        address _strategyCreator = strategies[getStorageId(wallet, _automation.strategyId)].creator;
        uint256 feeInToken =
            feeInUSD > 0 ? _payAutomation(wallet, _automation.paymentToken, feeInUSD, beneficary, _strategyCreator) : 0;

        _updateCondition(wallet, _automation.condition, id);

        emit AutomationExecuted(wallet, id, _automation.paymentToken, feeInToken, feeInUSD);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Internal functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _executeStrategy(address wallet, uint32 id) internal returns (uint256 fee) {
        fee = _executeStep(wallet, id, 0);

        emit StrategyExecuted(wallet, id);
    }

    function _executeStep(address wallet, uint32 id, uint16 index) internal returns (uint256 fee) {
        StrategyStep memory _step = strategies[getStorageId(wallet, id)].steps[index];

        //Check Condition
        (uint8 conditionResult, uint16 nextIndex) = _checkCondition(wallet, _step.condition);

        if (conditionResult == 1) {
            //Execute all actions from the step
            for (uint256 i = 0; i < _step.actions.length; i++) {
                uint256 _actionFee = _executeAction(wallet, _step.actions[i]);
                fee += _actionFee;
            }

            emit StrategyStepExecuted(wallet, id, index, _step.actions);
        }

        if (nextIndex != 0) {
            //if there is a next step go to it
            uint256 _feeNextStep = _executeStep(wallet, id, nextIndex);
            fee += _feeNextStep;
        }
    }

    function _executeAction(address _wallet, Action memory _action) internal returns (uint256 feeInUSD) {
        (address tokenToTrack, bool exist) =
            feeController.getTokenForAction(_action.target, _action.selector, _action.parameter);
        // If the volume token exist track the volume before and after the execution, else get the min fee

        uint256 preExecBalance = exist ? IERC20(tokenToTrack).balanceOf(_wallet) : 0;

        _execute(_wallet, _action);

        IFeeController.FeeType feeType = feeController.functionFeeConfig(_action.selector).feeType;

        if (exist) {
            uint256 postExecBalance = IERC20(tokenToTrack).balanceOf(_wallet);
            uint256 volume = feeType == IFeeController.FeeType.Deposit
                ? preExecBalance - postExecBalance
                : postExecBalance - preExecBalance;

            feeInUSD = feeController.calculateFee(tokenToTrack, _action.selector, volume);
        } else {
            feeInUSD = feeController.minFeeInUSD(feeType);
        }

        emit ActionExecuted(_wallet, _action);
    }

    function _execute(address _wallet, Action memory _action) internal {
        bytes memory data = abi.encodePacked(_action.selector, _action.parameter);
        if (_action.actionType == ActionType.EXTERNAL) {
            IPluginExecutor(_wallet).executeFromPluginExternal(_action.target, _action.value, data);
        } else {
            (, bytes memory _result) = _action.target.call(data);
            IAction.PluginExecution[] memory executions = abi.decode(_result, (IAction.PluginExecution[]));
            for (uint256 i = 0; i < executions.length; i++) {
                IPluginExecutor(_wallet).executeFromPluginExternal(
                    executions[i].target, executions[i].value, executions[i].data
                );
            }
        }
    }

    function _deleteAutomation(address wallet, uint32 id) internal {
        bytes32 automationSID = getStorageId(wallet, id);
        Automation memory _automation = automations[automationSID];

        uint32[] storage _usedInAutomations = strategiesUsed[getStorageId(wallet, _automation.strategyId)];

        uint32 _actualAutomationIndex = automationsToIndex[automationSID];
        uint256 _lastAutomationIndex = _usedInAutomations.length - 1;
        if (_actualAutomationIndex != _lastAutomationIndex) {
            uint32 _lastAutomation = _usedInAutomations[_lastAutomationIndex];
            _usedInAutomations[_actualAutomationIndex] = _lastAutomation;
            automationsToIndex[getStorageId(wallet, _lastAutomation)] = _actualAutomationIndex;
        }
        _usedInAutomations.pop();

        _changeAutomationInCondition(
            wallet, _automation.condition.conditionAddress, _automation.condition.id, id, false
        );

        delete automations[automationSID];

        emit AutomationDeleted(wallet, id);
    }

    function _checkCondition(address _wallet, Condition memory _condition)
        internal
        view
        returns (uint8 conditionResult, uint16 nextStep)
    {
        if (_condition.conditionAddress == address(0)) {
            nextStep = _condition.result1;
            conditionResult = 1;
        } else {
            conditionResult = ICondition(_condition.conditionAddress).checkCondition(_wallet, _condition.id);
            if (conditionResult == 1) {
                nextStep = _condition.result1;
            } else {
                nextStep = _condition.result0;
            }
        }
    }

    function _changeAutomationInCondition(
        address _wallet,
        address _condition,
        uint32 _conditionId,
        uint32 automationId,
        bool _add
    ) internal {
        if (!ICondition(_condition).conditionInAutomation(_wallet, _conditionId, automationId) == _add) {
            bytes memory data = _add
                ? abi.encodeCall(ICondition.addAutomationToCondition, (_conditionId, automationId))
                : abi.encodeCall(ICondition.removeAutomationFromCondition, (_conditionId, automationId));

            bytes memory result = IPluginExecutor(_wallet).executeFromPluginExternal(_condition, 0, data);
            bool _success = abi.decode(result, (bool));
            if (!_success) {
                revert changeAutomationInConditionFailed();
            }
        }
    }

    function _changeStrategyInCondition(
        address _wallet,
        address _condition,
        uint32 _conditionId,
        uint32 _strategy,
        bool _add
    ) internal {
        if (!ICondition(_condition).conditionInStrategy(_wallet, _conditionId, _strategy) == _add) {
            bytes memory data = _add
                ? abi.encodeCall(ICondition.addStrategyToCondition, (_conditionId, _strategy))
                : abi.encodeCall(ICondition.removeStrategyFromCondition, (_conditionId, _strategy));

            bytes memory result = IPluginExecutor(_wallet).executeFromPluginExternal(_condition, 0, data);
            bool _success = abi.decode(result, (bool));
            if (!_success) {
                revert ChangeStrategyInConditionFailed();
            }
        }
    }

    function _payAutomation(
        address wallet,
        address paymentToken,
        uint256 feeInUSD,
        address beneficiary,
        address creator
    ) internal returns (uint256) {
        //calculate the token amount
        uint256 feeInToken = feeController.calculateTokenAmount(paymentToken, feeInUSD);

        //If payment with ERC20 token approve first
        if (paymentToken != address(0)) {
            bytes memory _approveData = abi.encodeCall(IERC20.approve, (address(feeHandler), feeInToken));
            IPluginExecutor(wallet).executeFromPluginExternal(paymentToken, 0, _approveData);
        }

        bytes memory _handleFeeData = paymentToken != address(0)
            ? abi.encodeCall(IFeeHandler.handleFee, (paymentToken, feeInToken, beneficiary, creator))
            : abi.encodeCall(IFeeHandler.handleFeeETH, (beneficiary, creator));

        IPluginExecutor(wallet).executeFromPluginExternal(
            address(feeHandler), paymentToken == address(0) ? feeInToken : 0, _handleFeeData
        );

        return feeInToken;
    }

    function _updateCondition(address _wallet, Condition memory _condition, uint32 automationId) internal {
        if (ICondition(_condition.conditionAddress).isUpdateable(_wallet, _condition.id)) {
            bytes memory _data = abi.encodeCall(ICondition.updateCondition, (_condition.id));
            bytes memory _result =
                IPluginExecutor(_wallet).executeFromPluginExternal(_condition.conditionAddress, 0, _data);
            bool _success = abi.decode(_result, (bool));
            if (!_success) {
                revert UpdateConditionFailed(_condition.conditionAddress, _condition.id);
            }
        } else {
            _deleteAutomation(_wallet, automationId);
        }
    }

    function _validatePaymentToken(address token) internal view {
        bool valid = true;
        if (!feeController.hasOracle(token)) {
            valid = false;
        }

        if (!feeHandler.tokenAllowed(token)) {
            valid = false;
        }

        if (!valid) {
            revert PaymentTokenNotAllowed();
        }
    }

    function _validateSteps(StrategyStep[] memory steps) internal pure {
        for (uint256 i = 0; i < steps.length; i++) {
            _validateStep(steps[i], steps.length);
        }
    }

    function _validateStep(StrategyStep memory step, uint256 maxStepIndex) internal pure {
        if (step.condition.result0 > maxStepIndex || step.condition.result1 > maxStepIndex) {
            revert InvalidNextStepIndex();
        }
    }

    function _validateAction(Action memory action) internal view {
        if (action.actionType == ActionType.INTERNAL_ACTION) {
            if (!action.target.isContract()) {
                revert InvalidActionTarget();
            }
            if (IERC165(action.target).supportsInterface(type(IAction).interfaceId)) {
                revert InvalidActionTarget();
            }
        } else {
            if (action.target == address(0)) {
                revert InvalidActionTarget();
            }
        }
    }

    function _validateCondition(Condition memory condition) internal view {
        if (condition.conditionAddress != address(0)) {
            if (!condition.conditionAddress.isContract()) {
                revert InvalidConditionAddress();
            }

            if (!IERC165(condition.conditionAddress).supportsInterface(type(ICondition).interfaceId)) {
                revert InvalidCondition();
            }
        }
    }

    function _decodePluginExecutions(bytes memory encodedData)
        private
        pure
        returns (IAction.PluginExecution[] memory)
    {
        return abi.decode(encodedData, (IAction.PluginExecution[]));
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Plugin interface functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc BasePlugin
    function onInstall(bytes calldata) external pure override {}

    /// @inheritdoc BasePlugin
    function onUninstall(bytes calldata) external pure override {}

    /// @inheritdoc BasePlugin
    function pluginManifest() external pure override returns (PluginManifest memory) {
        PluginManifest memory manifest;

        // since we are using the modular account, we will specify one depedency
        // which will handle the user op validation for ownership
        // you can find this depedency specified in the installPlugin call in the tests
        manifest.dependencyInterfaceIds = new bytes4[](1);
        manifest.dependencyInterfaceIds[0] = type(IPlugin).interfaceId;

        manifest.executionFunctions = new bytes4[](5);
        manifest.executionFunctions[0] = this.createStrategy.selector;
        manifest.executionFunctions[1] = this.executeStrategy.selector;
        manifest.executionFunctions[2] = this.createAutomation.selector;
        manifest.executionFunctions[3] = this.deleteStrategy.selector;
        manifest.executionFunctions[4] = this.deleteAutomation.selector;

        // you can think of ManifestFunction as a reference to a function somewhere,
        // we want to say "use this function" for some purpose - in this case,
        // we'll be using the user op validation function from the single owner dependency
        // and this is specified by the depdendency index
        ManifestFunction memory ownerUserOpValidationFunction = ManifestFunction({
            functionType: ManifestAssociatedFunctionType.DEPENDENCY,
            functionId: 0, // unused since it's a dependency
            dependencyIndex: _MANIFEST_DEPENDENCY_INDEX_OWNER_USER_OP_VALIDATION
        });

        // here we will link together the increment function with the single owner user op validation
        // this basically says "use this user op validation function and make sure everythings okay before calling increment"
        // this will ensure that only an owner of the account can call increment
        manifest.userOpValidationFunctions = new ManifestAssociatedFunction[](5);
        manifest.userOpValidationFunctions[0] = ManifestAssociatedFunction({
            executionSelector: this.createStrategy.selector,
            associatedFunction: ownerUserOpValidationFunction
        });

        manifest.userOpValidationFunctions[1] = ManifestAssociatedFunction({
            executionSelector: this.executeStrategy.selector,
            associatedFunction: ownerUserOpValidationFunction
        });

        manifest.userOpValidationFunctions[2] = ManifestAssociatedFunction({
            executionSelector: this.createAutomation.selector,
            associatedFunction: ownerUserOpValidationFunction
        });

        manifest.userOpValidationFunctions[3] = ManifestAssociatedFunction({
            executionSelector: this.deleteStrategy.selector,
            associatedFunction: ownerUserOpValidationFunction
        });

        manifest.userOpValidationFunctions[4] = ManifestAssociatedFunction({
            executionSelector: this.deleteAutomation.selector,
            associatedFunction: ownerUserOpValidationFunction
        });

        // finally here we will always deny runtime calls to the increment function as we will only call it through user ops
        // this avoids a potential issue where a future plugin may define
        // a runtime validation function for it and unauthorized calls may occur due to that
        manifest.preRuntimeValidationHooks = new ManifestAssociatedFunction[](5);
        manifest.preRuntimeValidationHooks[0] = ManifestAssociatedFunction({
            executionSelector: this.createStrategy.selector,
            associatedFunction: ManifestFunction({
                functionType: ManifestAssociatedFunctionType.PRE_HOOK_ALWAYS_DENY,
                functionId: 0,
                dependencyIndex: 0
            })
        });

        manifest.preRuntimeValidationHooks[1] = ManifestAssociatedFunction({
            executionSelector: this.executeStrategy.selector,
            associatedFunction: ManifestFunction({
                functionType: ManifestAssociatedFunctionType.PRE_HOOK_ALWAYS_DENY,
                functionId: 0,
                dependencyIndex: 0
            })
        });

        manifest.preRuntimeValidationHooks[2] = ManifestAssociatedFunction({
            executionSelector: this.createAutomation.selector,
            associatedFunction: ManifestFunction({
                functionType: ManifestAssociatedFunctionType.PRE_HOOK_ALWAYS_DENY,
                functionId: 0,
                dependencyIndex: 0
            })
        });

        manifest.preRuntimeValidationHooks[3] = ManifestAssociatedFunction({
            executionSelector: this.deleteAutomation.selector,
            associatedFunction: ManifestFunction({
                functionType: ManifestAssociatedFunctionType.PRE_HOOK_ALWAYS_DENY,
                functionId: 0,
                dependencyIndex: 0
            })
        });

        manifest.preRuntimeValidationHooks[4] = ManifestAssociatedFunction({
            executionSelector: this.deleteStrategy.selector,
            associatedFunction: ManifestFunction({
                functionType: ManifestAssociatedFunctionType.PRE_HOOK_ALWAYS_DENY,
                functionId: 0,
                dependencyIndex: 0
            })
        });

        manifest.permitAnyExternalAddress = true;
        manifest.canSpendNativeToken = true;

        return manifest;
    }

    /// @inheritdoc BasePlugin
    function pluginMetadata() external pure virtual override returns (PluginMetadata memory) {
        PluginMetadata memory metadata;
        metadata.name = NAME;
        metadata.version = VERSION;
        metadata.author = AUTHOR;
        return metadata;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    External View Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc IStrategyBuilderPlugin
    function strategy(address wallet, uint32 id) external view returns (Strategy memory) {
        return strategies[getStorageId(wallet, id)];
    }

    /// @inheritdoc IStrategyBuilderPlugin
    function automation(address wallet, uint32 id) external view returns (Automation memory) {
        return automations[getStorageId(wallet, id)];
    }

    /// @inheritdoc IStrategyBuilderPlugin
    function getStorageId(address wallet, uint32 id) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(wallet, id));
    }
}
