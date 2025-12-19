// SPDX-License-Identifier:MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStrategyVault} from "./interfaces/IStrategyVault.sol";
import {ICondition} from "./interfaces/ICondition.sol";
import {IFeeController} from "./interfaces/IFeeController.sol";
import {IFeeHandler} from "./interfaces/IFeeHandler.sol";
import {IActionRegistry} from "./interfaces/IActionRegistry.sol";
import {IAction} from "./interfaces/IAction.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {TokenReceiver} from "./utils/TokenReceiver.sol";

/**
 * @title StrategyVault
 * @dev A module for creating, executing, and managing automated strategies based on predefined conditions and actions.
 */
contract StrategyVault is
    Initializable,
    TokenReceiver,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    IStrategyVault
{
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       StateVariable       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Fee controller contract
    IFeeController public feeController;

    /// @notice Fee handler contract
    IFeeHandler public feeHandler;

    /// @notice Action Registry contract
    IActionRegistry public actionRegistry;

    /// @notice Maps strategy IDs to strategy data
    mapping(uint32 => Strategy) private strategies;

    /// @notice Tracks where each strategy is used
    mapping(uint32 => uint32[]) private strategiesUsed;

    /// @notice Maps automation IDs to their index in the owner's strategy usage array
    mapping(uint32 => uint32) private automationsToIndex; //Maps each automation ID to its index in the owner's used strategy array.

    /// @notice Maps automation IDs to automation data
    mapping(uint32 => Automation) private automations;

    mapping(bytes32 => ActionContext) private globalContexts;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Modifier            ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    modifier strategyExist(uint32 id) {
        if (strategies[id].steps.length == 0) {
            revert StrategyDoesNotExist();
        }
        _;
    }

    modifier strategyDoesNotExist(uint32 id) {
        if (strategies[id].steps.length > 0) {
            revert StrategyAlreadyExist();
        }
        _;
    }

    modifier automationExist(uint32 id) {
        if (automations[id].condition.conditionAddress == address(0)) {
            revert AutomationNotExist();
        }
        _;
    }

    modifier automationDoesNotExist(uint32 id) {
        if (automations[id].condition.conditionAddress != address(0)) {
            revert AutomationAlreadyExist();
        }
        _;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Constructor         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the vault (called via proxy)
     * @param _owner The owner of the vault
     * @param _feeController The fee controller address
     * @param _feeHandler The fee handler address
     * @param _actionRegistry The action registry address
     *
     * @dev This replaces the constructor for upgradeable contracts
     * Use `initializer` modifier to prevent re-initialization
     */
    function initialize(address _owner, address _feeController, address _feeHandler, address _actionRegistry)
        public
        initializer
    {
        require(_owner != address(0), "Invalid owner");
        require(_feeController != address(0), "Invalid fee controller");
        require(_feeHandler != address(0), "Invalid fee handler");
        require(_actionRegistry != address(0), "Invalid action registry");

        // Initialize base contracts
        __Ownable_init(_owner);
        __ReentrancyGuard_init();

        // Set dependencies
        feeController = IFeeController(_feeController);
        feeHandler = IFeeHandler(_feeHandler);
        actionRegistry = IActionRegistry(_actionRegistry);
    }

    receive() external payable {}

    fallback() external payable {}

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function execute(address target, uint256 value, bytes calldata data)
        external
        payable
        onlyOwner
        returns (bytes memory result)
    {
        result = _exec(target, value, data);
    }

    function executeBatch(Call[] calldata calls) external payable onlyOwner returns (bytes[] memory results) {
        uint256 callsLength = calls.length;
        results = new bytes[](callsLength);

        for (uint256 i = 0; i < callsLength; ++i) {
            results[i] = _exec(calls[i].target, calls[i].value, calls[i].data);
        }
    }

    /// @inheritdoc IStrategyVault
    function createStrategy(uint32 id, address creator, StrategyStep[] calldata steps)
        external
        strategyDoesNotExist(id)
        onlyOwner
    {
        _createStrategy(id, creator, steps, bytes32(0));
    }

    function createStrategyWithExistingContext(
        uint32 id,
        address creator,
        StrategyStep[] calldata steps,
        bytes32 contextId
    ) external strategyDoesNotExist(id) onlyOwner {
        _createStrategy(id, creator, steps, contextId);
    }

    /// @inheritdoc IStrategyVault
    function deleteStrategy(uint32 id) external strategyExist(id) onlyOwner {
        if (strategiesUsed[id].length > 0) {
            revert StrategyIsInUse();
        }

        Strategy memory _strategy = strategies[id];

        for (uint256 i = 0; i < _strategy.steps.length; i++) {
            Condition memory condition = _strategy.steps[i].condition;
            if (condition.conditionAddress != address(0)) {
                _changeStrategyInCondition(msg.sender, condition.conditionAddress, condition.id, id, false);
            }
        }

        delete strategies[id];

        emit StrategyDeleted(id);
    }

    /// @inheritdoc IStrategyVault
    function executeStrategy(uint32 id) external strategyExist(id) nonReentrant onlyOwner {
        _executeStrategy(id);
    }

    /// @inheritdoc IStrategyVault
    function createAutomation(
        uint32 id,
        uint32 strategyId,
        address paymentToken,
        uint256 maxFeeInUSD,
        Condition calldata condition
    ) external automationDoesNotExist(id) strategyExist(strategyId) onlyOwner {
        //Specific validations
        _validatePaymentToken(paymentToken);

        _validateCondition(condition);

        _changeAutomationInCondition(condition.conditionAddress, condition.id, id, true);

        Automation storage _newAutomation = automations[id];

        _newAutomation.condition = condition;
        _newAutomation.strategyId = strategyId;

        _newAutomation.paymentToken = paymentToken;
        _newAutomation.maxFeeAmount = maxFeeInUSD;

        strategiesUsed[strategyId].push(id);
        automationsToIndex[id] = uint32(strategiesUsed[strategyId].length - 1);

        emit AutomationCreated(id, strategyId, condition, paymentToken, maxFeeInUSD);
    }

    /// @inheritdoc IStrategyVault
    function deleteAutomation(uint32 id) external automationExist(id) onlyOwner {
        _deleteAutomation(id);
    }

    /// @inheritdoc IStrategyVault
    function executeAutomation(uint32 id, address beneficary) external automationExist(id) nonReentrant {
        Automation memory _automation = automations[id];

        //Check the condition
        (uint8 conditionResult,) = _checkCondition(_automation.condition);

        if (conditionResult == 0) {
            revert AutomationNotExecutable(_automation.condition.conditionAddress, _automation.condition.id);
        }

        uint256 feeInUSD = _executeStrategy(_automation.strategyId);

        if (feeInUSD > _automation.maxFeeAmount) {
            revert FeeExceedMaxFee();
        }

        address _strategyCreator = strategies[_automation.strategyId].creator;
        uint256 feeInToken =
            feeInUSD > 0 ? _payAutomation(_automation.paymentToken, feeInUSD, beneficary, _strategyCreator) : 0;

        _updateCondition(_automation.condition, id);

        emit AutomationExecuted(id, _automation.paymentToken, feeInToken, feeInUSD);
    }

    function storeConextVariable(bytes32 contextId, bytes32 key, ParamType paramType, bytes memory value) external {
        if (!_hasValidKey(key)) revert InvalidContextKey();

        ActionContext storage context = globalContexts[contextId];

        _storeParamInContext(context, key, paramType, value);

        emit ContextVariableStored(contextId, key, value);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Context functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @dev Process action parameters by replacing values at specified offsets
     */
    function _processActionParameters(Action memory action, ActionContext storage context)
        internal
        view
        returns (bytes memory)
    {
        if (action.inputs.length == 0) {
            return action.parameter;
        }

        bytes memory processedParams = action.parameter;

        // Process each input replacement
        for (uint256 i = 0; i < action.inputs.length; i++) {
            ContextKey memory input = action.inputs[i];

            if (_hasValidKey(input.key)) {
                bytes memory replacementValue =
                    _getContextValueByType(context, input.key, input.parameterReplacement.paramType);

                if (replacementValue.length > 0) {
                    processedParams =
                        _replaceParameterAtOffset(processedParams, input.parameterReplacement, replacementValue);
                }
            }
        }

        return processedParams;
    }

    /**
     * @dev Get context value by type from global storage
     */
    function _getContextValueByType(ActionContext storage context, bytes32 key, ParamType paramType)
        internal
        view
        returns (bytes memory)
    {
        if (paramType == ParamType.UINT256) {
            uint256 amount = context.amounts[key];
            if (amount > 0 || context.variables[key].length > 0) {
                return amount > 0 ? abi.encode(amount) : context.variables[key];
            }
        } else if (paramType == ParamType.ADDRESS) {
            address addr = context.addresses[key];
            if (addr != address(0)) {
                return abi.encode(addr);
            }
        } else if (paramType == ParamType.BOOL) {
            // Check if boolean was explicitly set
            if (context.variables[key].length > 0) {
                bool value = context.booleans[key];
                return abi.encode(value);
            }
        } else if (paramType == ParamType.BYTES32) {
            bytes memory data = context.variables[key];
            if (data.length >= 32) {
                return data;
            }
        }

        // Fallback to raw variables
        return context.variables[key];
    }

    /**
     * @dev Replace parameter value at specific offset
     */
    function _replaceParameterAtOffset(bytes memory parameters, Parameter memory param, bytes memory replacement)
        internal
        pure
        returns (bytes memory)
    {
        require(param.offset + param.length <= parameters.length, "Invalid parameter offset");
        require(replacement.length >= param.length, "Replacement too short");

        // Replace bytes at the specified offset
        for (uint256 i = 0; i < param.length; i++) {
            parameters[param.offset + i] = replacement[i];
        }

        return parameters;
    }

    function _storeToGlobalContext(bytes32 contextId, ContextKey memory outputKey, bytes memory result) internal {
        if (!_hasValidKey(outputKey.key)) return;

        ActionContext storage globalContext = globalContexts[contextId];

        require(
            outputKey.parameterReplacement.offset + outputKey.parameterReplacement.length <= result.length,
            "Slice out of bounds"
        );

        // ---- SIMPLE BYTE SLICE ----
        bytes memory sliced = new bytes(outputKey.parameterReplacement.length);
        for (uint256 i; i < outputKey.parameterReplacement.length; i++) {
            sliced[i] = result[outputKey.parameterReplacement.offset + i];
        }

        // Store raw result
        globalContext.variables[outputKey.key] = sliced;

        _storeParamInContext(globalContext, outputKey.key, outputKey.parameterReplacement.paramType, sliced);
        // BYTES32 is stored as raw variables

        emit ContextVariableStored(contextId, outputKey.key, sliced);
    }

    function _storeParamInContext(ActionContext storage context, bytes32 key, ParamType paramType, bytes memory result)
        internal
    {
        if (paramType == ParamType.UINT256) {
            if (result.length >= 32) {
                uint256 value = abi.decode(result, (uint256));
                context.amounts[key] = value;
            }
        } else if (paramType == ParamType.ADDRESS) {
            if (result.length >= 32) {
                address addr = abi.decode(result, (address));
                context.addresses[key] = addr;
            }
        } else if (paramType == ParamType.BOOL) {
            if (result.length >= 32) {
                bool value = abi.decode(result, (bool));
                context.booleans[key] = value;
            }
        }
    }

    function _hasValidKey(bytes32 key) internal pure returns (bool) {
        return key != bytes32(0);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Internal functions         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function _exec(address target, uint256 value, bytes memory data) internal returns (bytes memory result) {
        bool success;
        (success, result) = target.call{value: value}(data);

        if (!success) {
            // Directly bubble up revert messages
            assembly ("memory-safe") {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function _createStrategy(uint32 id, address creator, StrategyStep[] calldata steps, bytes32 contextId)
        internal
        strategyDoesNotExist(id)
    {
        _validateSteps(steps);

        Strategy storage newStrategy = strategies[id];

        newStrategy.creator = creator;

        newStrategy.contextId = contextId == bytes32(0)
            ? keccak256(abi.encodePacked(msg.sender, id, block.timestamp, block.number))
            : contextId;

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

                Action memory _currAction = step.actions[j];
                Action storage newAction = newStep.actions.push();

                newAction.target = _currAction.target;
                newAction.parameter = _currAction.parameter;
                newAction.value = _currAction.value;
                newAction.selector = _currAction.selector;
                newAction.actionType = _currAction.actionType;

                newAction.output = _currAction.output;
                newAction.result = _currAction.result;

                // Save the input keys for this action into the new step's actions
                // Create a copy of the input keys array
                uint256 inputCount = step.actions[j].inputs.length;
                for (uint256 k = 0; k < inputCount; k++) {
                    newAction.inputs.push(step.actions[j].inputs[k]);
                }
            }
        }

        emit StrategyCreated(id, creator, newStrategy.contextId, newStrategy);
    }

    function _executeStrategy(uint32 id) internal returns (uint256 fee) {
        fee = _executeStep(0, id);

        emit StrategyExecuted(id);
    }

    function _executeStep(uint16 index, uint32 strategyId) internal returns (uint256 fee) {
        StrategyStep memory _step = strategies[strategyId].steps[index];

        //Check Condition
        (uint8 conditionResult, uint16 nextIndex) = _checkCondition(_step.condition);

        if (conditionResult == 1) {
            //Execute all actions from the step
            for (uint256 i = 0; i < _step.actions.length; i++) {
                uint256 _actionFee = _executeAction(_step.actions[i], strategies[strategyId].contextId);
                fee += _actionFee;
            }

            emit StrategyStepExecuted(strategyId, index, _step.actions);
        }

        if (nextIndex != 0) {
            //if there is a next step go to it
            uint256 _feeNextStep = _executeStep(nextIndex, strategyId);
            fee += _feeNextStep;
        }
    }

    function _executeAction(Action memory _action, bytes32 contextId) internal returns (uint256 feeInUSD) {
        (address tokenToTrack, bool exist) =
            feeController.getTokenForAction(_action.target, _action.selector, _action.parameter);
        // If the volume token exist track the volume before and after the execution, else get the min fee

        uint256 preExecBalance = exist ? IERC20(tokenToTrack).balanceOf(address(this)) : 0;

        _execute(_action, contextId);

        IFeeController.FeeType feeType = feeController.functionFeeConfig(_action.selector).feeType;

        if (exist) {
            uint256 postExecBalance = IERC20(tokenToTrack).balanceOf(address(this));
            uint256 volume = feeType == IFeeController.FeeType.Deposit
                ? preExecBalance - postExecBalance
                : postExecBalance - preExecBalance;

            feeInUSD = feeController.calculateFee(tokenToTrack, _action.selector, volume);
        } else {
            feeInUSD = feeController.minFeeInUSD();
        }

        emit ActionExecuted(_action);
    }

    function _execute(Action memory _action, bytes32 contextId) internal {
        bytes memory executionParams = _action.parameter;
        if (_action.inputs.length > 0) {
            executionParams = _processActionParameters(_action, globalContexts[contextId]);
        }

        bytes memory data =
            _action.selector == bytes4(0) ? bytes("") : abi.encodePacked(_action.selector, executionParams);

        bytes memory executionResult;
        if (_action.actionType == ActionType.EXTERNAL) {
            (, executionResult) = _action.target.call{value: _action.value}(data);
        } else {
            (, bytes memory _result) = _action.target.call(data);

            bool hasStoreResult = _hasStoreResult(_result);

            if (hasStoreResult) {
                (IAction.PluginExecution[] memory executions, bytes memory actionCallResult) =
                    abi.decode(_result, (IAction.PluginExecution[], bytes));

                executionResult = _executePluginsAndGetResult(executions, _action.result, actionCallResult);
            } else {
                IAction.PluginExecution[] memory executions = abi.decode(_result, (IAction.PluginExecution[]));

                executionResult = _executePluginsAndGetResult(executions, _action.result, "");
            }
        }

        if (_action.output.key != bytes32(0)) {
            _storeToGlobalContext(contextId, _action.output, executionResult);
        }
    }

    function _hasStoreResult(bytes memory data) internal pure returns (bool) {
        // Check if the data starts with a tuple containing 2 elements
        // This is a simplified check - you might want more robust detection
        if (data.length < 64) return false;

        // Try to peek at the structure
        uint256 firstOffset;
        uint256 secondOffset;

        assembly {
            firstOffset := mload(add(data, 0x20)) // First element offset
            secondOffset := mload(add(data, 0x40)) // Second element offset
        }

        // If we have two valid offsets, it's likely a tuple with 2 elements
        return firstOffset > 0 && secondOffset > firstOffset;
    }

    function _executePluginsAndGetResult(
        IAction.PluginExecution[] memory executions,
        uint256 resultIndex,
        bytes memory actionCallResult
    ) internal returns (bytes memory) {
        require(resultIndex <= executions.length, "Invalid execution index");

        bytes memory result;
        for (uint256 i = 0; i < executions.length; i++) {
            bytes memory _executionResult = _exec(executions[i].target, executions[i].value, executions[i].data);

            if (resultIndex == i + 1) {
                result = _executionResult;
            }
        }

        return resultIndex == 0 ? actionCallResult : result;
    }

    function _deleteAutomation(uint32 id) internal {
        Automation memory _automation = automations[id];

        uint32[] storage _usedInAutomations = strategiesUsed[_automation.strategyId];

        uint32 _actualAutomationIndex = automationsToIndex[id];
        uint256 _lastAutomationIndex = _usedInAutomations.length - 1;
        if (_actualAutomationIndex != _lastAutomationIndex) {
            uint32 _lastAutomation = _usedInAutomations[_lastAutomationIndex];
            _usedInAutomations[_actualAutomationIndex] = _lastAutomation;
            automationsToIndex[_lastAutomation] = _actualAutomationIndex;
        }
        _usedInAutomations.pop();

        _changeAutomationInCondition(_automation.condition.conditionAddress, _automation.condition.id, id, false);

        delete automations[id];
        delete automationsToIndex[id];

        emit AutomationDeleted(id);
    }

    function _checkCondition(Condition memory _condition)
        internal
        view
        returns (uint8 conditionResult, uint16 nextStep)
    {
        if (_condition.conditionAddress == address(0)) {
            nextStep = _condition.result1;
            conditionResult = 1;
        } else {
            conditionResult = ICondition(_condition.conditionAddress).checkCondition(address(this), _condition.id);
            if (conditionResult == 1) {
                nextStep = _condition.result1;
            } else {
                nextStep = _condition.result0;
            }
        }
    }

    function _changeAutomationInCondition(address _condition, uint32 _conditionId, uint32 automationId, bool _add)
        internal
    {
        if (!ICondition(_condition).conditionInAutomation(address(this), _conditionId, automationId) == _add) {
            bool _success = _add
                ? ICondition(_condition).addAutomationToCondition(_conditionId, automationId)
                : ICondition(_condition).removeAutomationFromCondition(_conditionId, automationId);

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
            bool _success = _add
                ? ICondition(_condition).addStrategyToCondition(_conditionId, _strategy)
                : ICondition(_condition).removeStrategyFromCondition(_conditionId, _strategy);

            if (!_success) revert ChangeStrategyInConditionFailed();
        }
    }

    function _payAutomation(address paymentToken, uint256 feeInUSD, address beneficiary, address creator)
        internal
        returns (uint256)
    {
        if (feeInUSD == 0) {
            return 0; // Early return for zero or disabled fees
        }

        uint256 feeInToken = feeController.calculateTokenAmount(paymentToken, feeInUSD);

        if (feeInToken == 0) return 0;

        //Check if primary Token is active and check the amount, if feeInPrimaryToken is lower than deposited, than pay with primary token
        if (feeHandler.primaryTokenActive()) {
            address primaryToken = feeHandler.primaryToken();
            uint256 feeInPrimaryToken = feeController.calculateTokenAmount(primaryToken, feeInUSD);
            uint256 primaryTokenDeposit = feeHandler.getDeposit(owner(), primaryToken);
            if (primaryTokenDeposit >= feeInPrimaryToken) {
                return IFeeHandler(address(feeHandler)).handleFeeWithVault(
                    primaryToken, feeInPrimaryToken, beneficiary, creator
                );
            }
        }

        uint256 deposit = feeHandler.getDeposit(owner(), paymentToken);

        uint256 remaining = deposit > feeInToken ? 0 : feeInToken - deposit;

        if (paymentToken != address(0) && remaining > 0) {
            IERC20(paymentToken).approve(address(feeHandler), feeInToken);
        }

        uint256 totalFee = paymentToken != address(0)
            ? IFeeHandler(address(feeHandler)).handleFeeWithVault(paymentToken, feeInToken, beneficiary, creator)
            : IFeeHandler(address(feeHandler)).handleFeeWithVaultETH{value: remaining}(feeInToken, beneficiary, creator);

        return totalFee;
    }

    function _updateCondition(Condition memory _condition, uint32 automationId) internal {
        if (ICondition(_condition.conditionAddress).isUpdateable(address(this), _condition.id)) {
            bool _success = ICondition(_condition.conditionAddress).updateCondition(_condition.id);

            if (!_success) revert UpdateConditionFailed(_condition.conditionAddress, _condition.id);
        } else {
            _deleteAutomation(automationId);
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
    // ┃    External View Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc IStrategyVault
    function strategy(uint32 id) external view returns (Strategy memory) {
        return strategies[id];
    }

    /// @inheritdoc IStrategyVault
    function automation(uint32 id) external view returns (Automation memory) {
        return automations[id];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(TokenReceiver) returns (bool) {
        return interfaceId == type(IStrategyVault).interfaceId || super.supportsInterface(interfaceId);
    }

    function getContextVariable(bytes32 contextId, bytes32 key) external view returns (bytes memory) {
        return globalContexts[contextId].variables[key];
    }
}
