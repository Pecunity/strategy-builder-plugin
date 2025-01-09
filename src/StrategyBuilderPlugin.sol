// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

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
import {IFeeManager} from "./interfaces/IFeeManager.sol";
import {IInkwell} from "./interfaces/IInkwell.sol";

error StrategyBuilderPlugin__StrategyDoesNotExist();
error StrategyBuilderPlugin__StrategyAlreadyExist();
error StrategyBuilderPlugin__AutomationNotExecutable(address condition, uint16 id);
error StrategyBuilderPlugin__FeeExceedMaxFee();
error StrategyBuilderPlugin__AutomationNotExist();
error StrategyBuilderPlugin__AutomationAlreadyExist();
error StrategyBuilderPlugin__StrategyIsInUse();
error StrategyBuilderPlugin__ChangeActionInConditionFailed();
error StrategyBuilderPlugin__ChangeStrategyInConditionFailed();
error StrategyBuilderPlugin__UpdateConditionFailed(address condition, uint16 id);

contract StrategyBuilderPlugin is BasePlugin, IStrategyBuilderPlugin {
    // metadata used by the pluginMetadata() method down below
    string public constant NAME = "Strategy Builder Plugin";
    string public constant VERSION = "0.0.1";
    string public constant AUTHOR = "3Blocks";

    // this is a constant used in the manifest, to reference our only dependency: the single owner plugin
    // since it is the first, and only, plugin the index 0 will reference the single owner plugin
    // we can use this to tell the modular account that we should use the single owner plugin to validate our user op
    // in other words, we'll say "make sure the person calling increment is an owner of the account using our single plugin"
    uint256 internal constant _MANIFEST_DEPENDENCY_INDEX_OWNER_USER_OP_VALIDATION = 0;

    IFeeManager public immutable feeManager;

    mapping(address => mapping(uint16 => Strategy)) private strategies;
    mapping(address => mapping(uint16 => uint16[])) private strategiesUsed; //All automations where the strategy is used
    mapping(address => mapping(uint16 => uint16)) private automationsToIndex; //Maps each automation ID to its index in the owner's used strategy array.
    mapping(address => mapping(uint16 => Automation)) private automations;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Modifier            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    modifier strategyExist(uint16 _id) {
        if (strategies[msg.sender][_id].steps.length == 0) {
            revert StrategyBuilderPlugin__StrategyDoesNotExist();
        }
        _;
    }

    modifier strategyDoesNotExist(uint16 _id) {
        if (strategies[msg.sender][_id].steps.length > 0) {
            revert StrategyBuilderPlugin__StrategyAlreadyExist();
        }
        _;
    }

    modifier automationExist(uint16 _id) {
        if (automations[msg.sender][_id].condition.conditionAddress == address(0)) {
            revert StrategyBuilderPlugin__AutomationNotExist();
        }
        _;
    }

    modifier automationDoesNotExist(uint16 _id) {
        if (automations[msg.sender][_id].condition.conditionAddress != address(0)) {
            revert StrategyBuilderPlugin__AutomationAlreadyExist();
        }
        _;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    constructor(address _feeManager) {
        feeManager = IFeeManager(_feeManager);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function addStrategy(uint16 _id, address _creator, StrategyStep[] calldata _steps)
        external
        strategyDoesNotExist(_id)
    {
        Strategy storage newStrategy = strategies[msg.sender][_id];

        newStrategy.creator = _creator;

        for (uint256 i = 0; i < _steps.length; i++) {
            StrategyStep memory step = _steps[i];

            // Create a new step in storage
            StrategyStep storage newStep = newStrategy.steps.push();
            newStep.condition = step.condition;

            if (step.condition.conditionAddress != address(0)) {
                _changeStrategyInCondition(msg.sender, step.condition.conditionAddress, step.condition.id, _id, true);
            }

            // Loop through the actions and add them to the step
            for (uint256 j = 0; j < step.actions.length; j++) {
                newStep.actions.push(step.actions[j]);
            }
        }

        emit StrategyAdded(_id, _creator, newStrategy);
    }

    function deleteStrategy(uint16 _id) external strategyExist(_id) {
        if (strategiesUsed[msg.sender][_id].length > 0) {
            revert StrategyBuilderPlugin__StrategyIsInUse();
        }

        Strategy memory _strategy = strategies[msg.sender][_id];

        for (uint256 i = 0; i < _strategy.steps.length; i++) {
            Condition memory _condition = _strategy.steps[i].condition;
            if (_condition.conditionAddress != address(0)) {
                _changeStrategyInCondition(msg.sender, _condition.conditionAddress, _condition.id, _id, false);
            }
        }

        delete strategies[msg.sender][_id];

        emit StrategyDeleted(_id);
    }

    function executeStrategy(uint16 _id) external strategyExist(_id) {
        _executeStrategy(msg.sender, _id);
    }

    function activateAutomation(
        uint16 _id,
        uint16 _strategyId,
        address _paymentToken,
        uint256 _maxFeeAmount,
        Condition calldata _condition
    ) external automationDoesNotExist(_id) strategyExist(_strategyId) {
        _changeActionInCondition(msg.sender, _condition.conditionAddress, _condition.id, _id, true);

        Automation storage _newAutomation = automations[msg.sender][_id];

        _newAutomation.condition = _condition;
        _newAutomation.strategyId = _strategyId;
        _newAutomation.paymentToken = _paymentToken;
        _newAutomation.maxFeeAmount = _maxFeeAmount;

        strategiesUsed[msg.sender][_strategyId].push(_id);
        automationsToIndex[msg.sender][_id] = uint16(strategiesUsed[msg.sender][_strategyId].length - 1);

        emit AutomationActivated(_id, _strategyId, _condition, _paymentToken, _maxFeeAmount);
    }

    function deleteAutomation(uint16 _id) external automationExist(_id) {
        Automation memory _automation = automations[msg.sender][_id];

        uint16[] storage _usedInAutomations = strategiesUsed[msg.sender][_automation.strategyId];

        uint16 _actualAutomationIndex = automationsToIndex[msg.sender][_id];
        uint256 _lastAutomationIndex = _usedInAutomations.length - 1;
        if (_actualAutomationIndex != _lastAutomationIndex) {
            uint16 _lastAutomation = _usedInAutomations[_lastAutomationIndex];
            _usedInAutomations[_actualAutomationIndex] = _lastAutomation;
            automationsToIndex[msg.sender][_lastAutomation] = _actualAutomationIndex;
        }
        _usedInAutomations.pop();

        _changeActionInCondition(
            msg.sender, _automation.condition.conditionAddress, _automation.condition.id, _id, false
        );

        delete automations[msg.sender][_id];

        emit AutomationDeleted(_id);
    }

    function executeAutomation(uint16 _id, address _wallet, address _beneficary) external {
        Automation memory _automation = automations[_wallet][_id];

        //Check the condition
        (uint8 _conditionResult,) = _checkCondition(_wallet, _automation.condition);

        if (_conditionResult == 0) {
            revert StrategyBuilderPlugin__AutomationNotExecutable(
                _automation.condition.conditionAddress, _automation.condition.id
            );
        }

        uint256 _feeNetto = _executeStrategy(_wallet, _automation.strategyId);

        //Calculate the resultant fee
        uint256 _resultantFee = feeManager.prepareForPayment(_feeNetto, _automation.paymentToken);

        if (_resultantFee > _automation.maxFeeAmount) {
            revert StrategyBuilderPlugin__FeeExceedMaxFee();
        }

        address _strategyCreator = strategies[_wallet][_automation.strategyId].creator;
        _payAutomation(_wallet, _automation.paymentToken, _resultantFee, _beneficary, _strategyCreator);

        _updateCondition(_wallet, _automation.condition, _id);

        emit AutomationExecuted(_id, _automation.paymentToken, _resultantFee);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Internal functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _executeStrategy(address _wallet, uint16 _id) internal returns (uint256 fee) {
        fee = _executeStep(_wallet, _id, 0);

        emit StrategyExecuted(_id);
    }

    function _executeStep(address _wallet, uint16 _id, uint16 _index) internal returns (uint256 fee) {
        StrategyStep memory _step = strategies[_wallet][_id].steps[_index];

        //Check Condition
        (uint8 _conditionResult, uint16 _nextIndex) = _checkCondition(_wallet, _step.condition);

        if (_conditionResult == 1) {
            //Execute all actions from the step
            for (uint256 i = 0; i < _step.actions.length; i++) {
                uint256 _actionFee = _executeAction(_wallet, _step.actions[i]);
                fee += _actionFee;
            }

            emit StrategyStepExecuted(_id, _index, _step.actions);
        }

        if (_nextIndex != 0) {
            //if there is a next step go to it
            uint256 _feeNextStep = _executeStep(_wallet, _id, _nextIndex);
            fee += _feeNextStep;
        }
    }

    function _executeAction(address _wallet, Action memory _action) internal returns (uint256) {
        IFeeManager.FeeType _feeType = feeManager.getFeeType(_action.selector);

        if (_feeType == IFeeManager.FeeType.PostCallFee) {
            address _basisFeeToken = feeManager.getBasisFeeToken(_action.selector, _action.parameter);
            uint256 _tokenBalance = IERC20(_basisFeeToken).balanceOf(_wallet);
            _execute(_wallet, _action);
            return feeManager.calculateFeeForPostCallAction(
                _action.selector, _basisFeeToken, IERC20(_basisFeeToken).balanceOf(_wallet) - _tokenBalance
            );
        } else if (_feeType == IFeeManager.FeeType.FixedFee) {
            _execute(_wallet, _action);
            return feeManager.getFixedFee(_action.selector);
        } else {
            _execute(_wallet, _action);
            return feeManager.calculateFeeForPreCallAction(_action.selector, _action.parameter);
        }
    }

    function _execute(address _wallet, Action memory _action) internal {
        bytes memory data = abi.encodePacked(_action.selector, _action.parameter);
        if (_action.actionType == ActionType.EXTERNAL) {
            IPluginExecutor(_wallet).executeFromPluginExternal(_action.target, _action.value, data);
        } else {
            IPluginExecutor(_wallet).executeFromPlugin(data);
        }
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

    function _changeActionInCondition(
        address _wallet,
        address _condition,
        uint16 _conditionId,
        uint16 _action,
        bool _add
    ) internal {
        bytes memory data = _add
            ? abi.encodeCall(ICondition.addAutomationToCondition, (_conditionId, _action))
            : abi.encodeCall(ICondition.removeAutomationFromCondition, (_conditionId, _action));

        bytes memory result = IPluginExecutor(_wallet).executeFromPluginExternal(_condition, 0, data);
        bool _success = abi.decode(result, (bool));
        if (!_success) {
            revert StrategyBuilderPlugin__ChangeActionInConditionFailed();
        }
    }

    function _changeStrategyInCondition(
        address _wallet,
        address _condition,
        uint16 _conditionId,
        uint16 _strategy,
        bool _add
    ) internal {
        bytes memory data = _add
            ? abi.encodeCall(ICondition.addStrategyToCondition, (_conditionId, _strategy))
            : abi.encodeCall(ICondition.removeStrategyFromCondition, (_conditionId, _strategy));

        bytes memory result = IPluginExecutor(_wallet).executeFromPluginExternal(_condition, 0, data);
        bool _success = abi.decode(result, (bool));
        if (!_success) {
            revert StrategyBuilderPlugin__ChangeStrategyInConditionFailed();
        }
    }

    function _payAutomation(address _wallet, address _paymentToken, uint256 _fee, address _beneficary, address _creator)
        internal
    {
        bytes memory _approveData = abi.encodeCall(IERC20.approve, (address(feeManager), _fee));
        IPluginExecutor(_wallet).executeFromPluginExternal(
            _paymentToken == address(0) ? feeManager.octoInk() : _paymentToken, 0, _approveData
        );

        bytes memory _handleFeeData =
            abi.encodeCall(IFeeManager.handleFee, (_fee, _beneficary, _creator, _paymentToken));
        IPluginExecutor(_wallet).executeFromPluginExternal(address(feeManager), 0, _handleFeeData);
    }

    function _updateCondition(address _wallet, Condition memory _condition, uint16 _actionId) internal {
        if (ICondition(_condition.conditionAddress).isUpdateable(_wallet, _condition.id)) {
            bytes memory _data = abi.encodeCall(ICondition.updateCondition, (_condition.id));
            bytes memory _result =
                IPluginExecutor(_wallet).executeFromPluginExternal(_condition.conditionAddress, 0, _data);
            bool _success = abi.decode(_result, (bool));
            if (!_success) {
                revert StrategyBuilderPlugin__UpdateConditionFailed(_condition.conditionAddress, _condition.id);
            }
        } else {
            _changeActionInCondition(_wallet, _condition.conditionAddress, _condition.id, _actionId, false);
        }
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
        manifest.executionFunctions[0] = this.addStrategy.selector;
        manifest.executionFunctions[1] = this.executeStrategy.selector;
        manifest.executionFunctions[2] = this.activateAutomation.selector;
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
            executionSelector: this.addStrategy.selector,
            associatedFunction: ownerUserOpValidationFunction
        });

        manifest.userOpValidationFunctions[1] = ManifestAssociatedFunction({
            executionSelector: this.executeStrategy.selector,
            associatedFunction: ownerUserOpValidationFunction
        });

        manifest.userOpValidationFunctions[2] = ManifestAssociatedFunction({
            executionSelector: this.activateAutomation.selector,
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
            executionSelector: this.addStrategy.selector,
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
            executionSelector: this.activateAutomation.selector,
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

    function strategy(address _wallet, uint16 _id) external view returns (Strategy memory) {
        return strategies[_wallet][_id];
    }

    function automation(address _wallet, uint16 _id) external view returns (Automation memory) {
        return automations[_wallet][_id];
    }
}
