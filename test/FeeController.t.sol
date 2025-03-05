// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FeeController} from "../src/FeeController.sol";
import {IFeeController} from "../src/interfaces/IFeeController.sol";
import {ITokenGetter} from "../src/interfaces/ITokenGetter.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";

contract FeeControllerTest is Test {
    FeeController controller;

    address public OWNER = makeAddr("owner");
    address public BAD_ACTOR = makeAddr("bad-actor");
    address public ORACLE = makeAddr("oracle");

    function setUp() external {
        vm.prank(OWNER);
        controller = new FeeController(ORACLE);
    }

    function test_deployment_Success() external {
        FeeController _newController = new FeeController(ORACLE);

        assertEq(_newController.priceOracle(), ORACLE);

        assertEq(_newController.minFeeInUSD(IFeeController.FeeType.Withdraw), 2e18);
        assertEq(_newController.minFeeInUSD(IFeeController.FeeType.Deposit), 1e18);
        assertEq(_newController.minFeeInUSD(IFeeController.FeeType.Reward), 0.5e18);
    }

    function test_deployment_OracleZeroAddress() external {
        vm.expectRevert(IFeeController.ZeroAddressNotValid.selector);
        new FeeController(address(0));
    }

    function test_setFunctionFeeConfig_Success(bytes4 _selector) external {
        uint256 _feePercentage = 100; //1%

        IFeeController.FeeType _feeType = IFeeController.FeeType.Withdraw;

        vm.prank(OWNER);
        controller.setFunctionFeeConfig(_selector, _feeType, _feePercentage);

        //Assert
        IFeeController.FeeConfig memory config = controller.functionFeeConfig(_selector);

        assertEq(config.feePercentage, _feePercentage);

        assertEq(uint8(config.feeType), uint8(_feeType));
    }

    function test_setFunctionFeeConfig_FeePercentageExceedMax(bytes4 _selector) external {
        IFeeController.FeeType _feeType = IFeeController.FeeType.Withdraw;

        uint256 _maxFee = controller.maxFeeLimit(_feeType);

        uint256 _feePercentage = _maxFee + 1;

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(IFeeController.FeePercentageExceedLimit.selector));
        controller.setFunctionFeeConfig(_selector, _feeType, _feePercentage);
    }

    function test_setTokenGetter_Success(bytes4 _selector, address _tokenGetter, address _target) external {
        vm.assume(_tokenGetter != address(0));
        vm.assume(_target != address(0));

        vm.prank(OWNER);
        controller.setTokenGetter(_selector, _tokenGetter, _target);

        //Assert
        assertEq(controller.tokenGetter(_target, _selector), _tokenGetter);
    }

    function test_setTokenGetter_ZeroAddress(bytes4 _selector, address _tokenGetter, address _target) external {
        address _modTarget = _target;
        if (_tokenGetter != address(0) && _target != address(0)) {
            _modTarget = address(0);
        }

        vm.prank(OWNER);
        vm.expectRevert(IFeeController.ZeroAddressNotValid.selector);
        controller.setTokenGetter(_selector, _tokenGetter, _modTarget);
    }

    function test_setGlobalTokenGetter_Success(bytes4 _selector, address _tokenGetter, address _target) external {
        vm.assume(_tokenGetter != address(0));

        vm.prank(OWNER);
        controller.setGlobalTokenGetter(_selector, _tokenGetter);

        assertEq(controller.tokenGetter(_target, _selector), _tokenGetter);
    }

    function test_setGlobalTokenGetter_ZeroAddress(bytes4 _selector) external {
        address _tokenGetter = address(0);

        vm.prank(OWNER);
        vm.expectRevert(IFeeController.ZeroAddressNotValid.selector);
        controller.setGlobalTokenGetter(_selector, _tokenGetter);
    }

    function test_getTokenForAction_ReturnTrue(address _target, bytes4 _selector) external {
        vm.assume(_target != address(0));

        bytes memory _params = generateRandomBytes(22);

        address _tokenGetter = makeAddr("token-getter-contract");
        address _token = makeAddr("token");
        vm.mockCall(
            _tokenGetter, abi.encodeCall(ITokenGetter.getTokenForSelector, (_selector, _params)), abi.encode(_token)
        );

        vm.prank(OWNER);

        controller.setTokenGetter(_selector, _tokenGetter, _target);

        (address _resultToken, bool result) = controller.getTokenForAction(_target, _selector, _params);

        assertEq(result, true);
        assertEq(_resultToken, _token);
    }

    function test_getTokenForAction_ReturnFalse(address _target, bytes4 _selector) external {
        bytes memory _params = generateRandomBytes(22);

        (address _resultToken, bool result) = controller.getTokenForAction(_target, _selector, _params);

        assertEq(result, false);
        assertEq(_resultToken, address(0));
    }

    function test_calculateFee_NoOracle(address _token, bytes4 _selector, uint256 _volume) external {
        vm.mockCall(ORACLE, abi.encodeCall(IPriceOracle.oracleID, (_token)), abi.encode(bytes32(0)));

        uint256 _minFee = controller.minFeeInUSD(controller.functionFeeConfig(_selector).feeType);

        assertEq(controller.calculateFee(_token, _selector, _volume), _minFee);
    }

    function test_calculateFee_FeeLowerMinFee(address _token, bytes4 _selector) external {
        uint256 _feePercentage = 100; //1%

        IFeeController.FeeType _feeType = IFeeController.FeeType.Withdraw;

        vm.prank(OWNER);
        controller.setFunctionFeeConfig(_selector, _feeType, _feePercentage);

        uint256 _minFee = controller.minFeeInUSD(controller.functionFeeConfig(_selector).feeType);

        uint256 _volumeInUSD = (controller.PERCENTAGE_DIVISOR() * _minFee / _feePercentage) - uint256(1);

        bytes32 _oralceID = getRandomBytes32();
        vm.mockCall(ORACLE, abi.encodeCall(IPriceOracle.oracleID, (_token)), abi.encode(_oralceID));
        vm.mockCall(ORACLE, abi.encodeCall(IPriceOracle.getTokenPrice, (_token)), abi.encode(1 ether));

        assertEq(controller.calculateFee(_token, _selector, _volumeInUSD), _minFee);
    }

    function test_calculateFee_FeeHigherMinFee(address _token, bytes4 _selector) external {
        uint256 _feePercentage = 100; //1%

        IFeeController.FeeType _feeType = IFeeController.FeeType.Withdraw;

        vm.prank(OWNER);
        controller.setFunctionFeeConfig(_selector, _feeType, _feePercentage);

        uint256 _minFee = controller.minFeeInUSD(controller.functionFeeConfig(_selector).feeType);

        uint256 _volume = (controller.PERCENTAGE_DIVISOR() * _minFee / _feePercentage) + uint256(2);

        bytes32 _oralceID = getRandomBytes32();
        vm.mockCall(ORACLE, abi.encodeCall(IPriceOracle.oracleID, (_token)), abi.encode(_oralceID));
        vm.mockCall(ORACLE, abi.encodeCall(IPriceOracle.getTokenPrice, (_token)), abi.encode(2 ether));

        uint256 _expFee = (_volume * 2 ether / 1e18) * _feePercentage / controller.PERCENTAGE_DIVISOR();
        assertEq(controller.calculateFee(_token, _selector, _volume), _expFee);
    }

    function test_calculateTokenAmount_Success(address token, uint256 price) external {
        vm.assume(price > 0);

        uint256 feeInUSD = 200 * 1e18; //200 USD

        bytes32 _oralceID = getRandomBytes32();
        vm.mockCall(ORACLE, abi.encodeCall(IPriceOracle.oracleID, (token)), abi.encode(_oralceID));
        vm.mockCall(ORACLE, abi.encodeCall(IPriceOracle.getTokenPrice, (token)), abi.encode(price));

        uint256 expAmount = feeInUSD * 1e18 / price;

        assertEq(expAmount, controller.calculateTokenAmount(token, feeInUSD));
    }

    function test_calculateTokenAmount_NoOracle(address token) external {
        vm.mockCall(ORACLE, abi.encodeCall(IPriceOracle.oracleID, (token)), abi.encode(bytes32(0)));

        vm.expectRevert(IFeeController.NoOracleExist.selector);
        controller.calculateTokenAmount(token, 200);
    }

    function test_calculateTokenAmount_PriceZero(address token) external {
        uint256 feeInUSD = 200 * 1e18; //200 USD

        bytes32 _oralceID = getRandomBytes32();
        vm.mockCall(ORACLE, abi.encodeCall(IPriceOracle.oracleID, (token)), abi.encode(_oralceID));
        vm.mockCall(ORACLE, abi.encodeCall(IPriceOracle.getTokenPrice, (token)), abi.encode(0));

        vm.expectRevert(IFeeController.InvalidTokenWithPriceOfZero.selector);
        controller.calculateTokenAmount(token, feeInUSD);
    }

    /* ====== HELPER FUNCTIONS ====== */

    function generateRandomBytes(uint256 length) internal view returns (bytes memory) {
        require(length > 0, "Length must be greater than zero");

        bytes memory randomBytes = new bytes(length);
        uint256 randomValue = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));

        for (uint256 i = 0; i < length; i++) {
            randomBytes[i] = bytes1(uint8(randomValue >> (i % 32)));
        }

        return randomBytes;
    }

    function getRandomBytes32() public view returns (bytes32) {
        return keccak256(abi.encodePacked(block.timestamp, msg.sender, block.prevrandao));
    }
}
