// SPDX-License-Identifier:MIT
pragma solidity ^0.8.28;

import {
    IExecutionModule,
    ExecutionManifest,
    ManifestExecutionFunction
} from "@erc6900/reference-implementation/interfaces/IExecutionModule.sol";
import {IModularAccount} from "@erc6900/reference-implementation/interfaces/IModularAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStrategyBuilderModule} from "./interfaces/IStrategyBuilderModule.sol";
import {ICondition} from "./interfaces/ICondition.sol";
import {IFeeController} from "./interfaces/IFeeController.sol";
import {IFeeHandler} from "./interfaces/IFeeHandler.sol";
import {IActionRegistry} from "./interfaces/IActionRegistry.sol";
import {IAction} from "./interfaces/IAction.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title StrategyBuilderModule
 * @dev A moodule for creating, executing, and managing automated strategies based on predefined conditions and actions.
 */
contract StrategyBuilderModule is ReentrancyGuard, IStrategyBuilderModule, IExecutionModule {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       StateVariable       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Fee controller contract
    IFeeController public immutable feeController;
    /// @notice Fee handler contract
    IFeeHandler public immutable feeHandler;
    /// @notice Action Registry contract
    IActionRegistry public immutable actionRegistry;

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
    /// @param _actionRegistry The address of the ActionRegistry contract used to validate allowed action contracts.
    constructor(address _feeController, address _feeHandler, address _actionRegistry) {
        feeController = IFeeController(_feeController);
        feeHandler = IFeeHandler(_feeHandler);
        actionRegistry = IActionRegistry(_actionRegistry);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc IStrategyBuilderModule
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

    /// @inheritdoc IStrategyBuilderModule
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

    /// @inheritdoc IStrategyBuilderModule
    function executeStrategy(uint32 id) external strategyExist(msg.sender, id) nonReentrant {
        _executeStrategy(msg.sender, id);
    }

    /// @inheritdoc IStrategyBuilderModule
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
        Automation storage _newAutomation = automations[automationSID];

        _newAutomation.condition = condition;
        _newAutomation.strategyId = strategyId;

        _newAutomation.paymentToken = paymentToken;
        _newAutomation.maxFeeAmount = maxFeeInUSD;

        bytes32 strategySID = getStorageId(msg.sender, strategyId);
        strategiesUsed[strategySID].push(id);
        automationsToIndex[automationSID] = uint32(strategiesUsed[strategySID].length - 1);

        emit AutomationCreated(msg.sender, id, strategyId, condition, paymentToken, maxFeeInUSD);
    }

    /// @inheritdoc IStrategyBuilderModule
    function deleteAutomation(uint32 id) external automationExist(msg.sender, id) {
        _deleteAutomation(msg.sender, id);
    }

    /// @inheritdoc IStrategyBuilderModule
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
        bytes memory data =
            _action.selector == bytes4(0) ? bytes("") : abi.encodePacked(_action.selector, _action.parameter);

        if (_action.actionType == ActionType.EXTERNAL) {
            IModularAccount(_wallet).execute(_action.target, _action.value, data);
        } else {
            (, bytes memory _result) = _action.target.call(data);
            IAction.PluginExecution[] memory executions = abi.decode(_result, (IAction.PluginExecution[]));
            for (uint256 i = 0; i < executions.length; i++) {
                IModularAccount(_wallet).execute(executions[i].target, executions[i].value, executions[i].data);
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
        delete automationsToIndex[automationSID];

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

            bytes memory result = IModularAccount(_wallet).execute(_condition, 0, data);
            bool _success = abi.decode(result, (bool));
            if (!_success) revert changeAutomationInConditionFailed();
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

            bytes memory result = IModularAccount(_wallet).execute(_condition, 0, data);
            bool _success = abi.decode(result, (bool));
            if (!_success) revert ChangeStrategyInConditionFailed();
        }
    }

    function _payAutomation(
        address wallet,
        address paymentToken,
        uint256 feeInUSD,
        address beneficiary,
        address creator
    ) internal returns (uint256) {
        uint256 feeInToken = feeController.calculateTokenAmount(paymentToken, feeInUSD);

        if (paymentToken != address(0)) {
            bytes memory _approveData = abi.encodeCall(IERC20.approve, (address(feeHandler), feeInToken));
            IModularAccount(wallet).execute(paymentToken, 0, _approveData);
        }

        bytes memory _handleFeeData = paymentToken != address(0)
            ? abi.encodeCall(IFeeHandler.handleFee, (paymentToken, feeInToken, beneficiary, creator))
            : abi.encodeCall(IFeeHandler.handleFeeETH, (beneficiary, creator));

        bytes memory paymentResult = IModularAccount(wallet).execute(
            address(feeHandler), paymentToken == address(0) ? feeInToken : 0, _handleFeeData
        );

        uint256 totalFee = abi.decode(paymentResult, (uint256));
        return totalFee;
    }

    function _updateCondition(address _wallet, Condition memory _condition, uint32 automationId) internal {
        if (ICondition(_condition.conditionAddress).isUpdateable(_wallet, _condition.id)) {
            bytes memory _data = abi.encodeCall(ICondition.updateCondition, (_condition.id));
            bytes memory _result = IModularAccount(_wallet).execute(_condition.conditionAddress, 0, _data);
            bool _success = abi.decode(_result, (bool));
            if (!_success) revert UpdateConditionFailed(_condition.conditionAddress, _condition.id);
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
        uint256 stepsLength = steps.length;
        if (stepsLength == 0) {
            revert InvalidStepArrayLength();
        }
        for (uint256 i = 0; i < stepsLength; i++) {
            _validateStep(steps[i], stepsLength, i);
        }
    }

    function _validateStep(StrategyStep memory step, uint256 maxStepIndex, uint256 stepIndex) internal pure {
        if (step.condition.result0 >= maxStepIndex || step.condition.result1 >= maxStepIndex) {
            revert InvalidNextStepIndex();
        }

        if (step.condition.conditionAddress == address(0) && step.actions.length == 0) {
            revert NoConditionOrActions(stepIndex);
        }
    }

    function _validateAction(Action memory action) internal view {
        if (action.actionType == ActionType.INTERNAL_ACTION) {
            if (!actionRegistry.isAllowed(action.target)) {
                revert InvalidActionTarget();
            }

            if (action.target.code.length == 0) {
                revert InvalidActionTarget();
            }
            try IERC165(action.target).supportsInterface(type(IAction).interfaceId) returns (bool valid) {
                if (!valid) {
                    revert InvalidActionTarget();
                }
            } catch {
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
            if (condition.conditionAddress.code.length == 0) {
                revert InvalidConditionAddress();
            }
            try IERC165(condition.conditionAddress).supportsInterface(type(ICondition).interfaceId) returns (bool valid)
            {
                if (!valid) {
                    revert InvalidCondition();
                }
            } catch {
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

    function onInstall(bytes calldata) external pure override {}

    function onUninstall(bytes calldata) external pure override {}

    function moduleId() external pure returns (string memory) {
        return "pecunity.strategy-builder-module";
    }

    function executionManifest() external pure returns (ExecutionManifest memory) {
        ExecutionManifest memory manifest;

        ManifestExecutionFunction[] memory executionFunctions = new ManifestExecutionFunction[](5);
        // 1. Publicly callable
        executionFunctions[0] = ManifestExecutionFunction({
            executionSelector: this.executeAutomation.selector,
            skipRuntimeValidation: true, // account owner can call
            allowGlobalValidation: false // no plugin-only validation
        });

        // 2. Internal-only functions
        executionFunctions[1] = ManifestExecutionFunction({
            executionSelector: this.createStrategy.selector,
            skipRuntimeValidation: false, // account owner can call
            allowGlobalValidation: true // no plugin-only validation
        });

        executionFunctions[2] = ManifestExecutionFunction({
            executionSelector: this.deleteStrategy.selector,
            skipRuntimeValidation: false, // account owner can call
            allowGlobalValidation: true // no plugin-only validation
        });

        executionFunctions[3] = ManifestExecutionFunction({
            executionSelector: this.createAutomation.selector,
            skipRuntimeValidation: false, // account owner can call
            allowGlobalValidation: true // no plugin-only validation
        });

        executionFunctions[4] = ManifestExecutionFunction({
            executionSelector: this.deleteAutomation.selector,
            skipRuntimeValidation: false, // account owner can call
            allowGlobalValidation: true // no plugin-only validation
        });

        manifest.executionFunctions = executionFunctions;

        return manifest;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    External View Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc IStrategyBuilderModule
    function strategy(address wallet, uint32 id) external view returns (Strategy memory) {
        return strategies[getStorageId(wallet, id)];
    }

    /// @inheritdoc IStrategyBuilderModule
    function automation(address wallet, uint32 id) external view returns (Automation memory) {
        return automations[getStorageId(wallet, id)];
    }

    /// @inheritdoc IStrategyBuilderModule
    function getStorageId(address wallet, uint32 id) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(wallet, id));
    }

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IStrategyBuilderModule).interfaceId;
    }
}
