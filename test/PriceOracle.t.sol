// SPDX-License-Identifier:MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {PriceOracle} from "contracts/PriceOracle.sol";
import {IPriceOracle} from "contracts/interfaces/IPriceOracle.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {MockPythReverting} from "contracts/test/mocks/MockPythReverting.sol";

contract PriceOracleTest is Test {
    PriceOracle oracle;

    address public PYTH_ORACLE = makeAddr("oracle");
    address public OWNER = makeAddr("owner");
    address public BAD_ACTOR = makeAddr("bad-actor");

    function setUp() external {
        vm.prank(OWNER);
        oracle = new PriceOracle(OWNER, PYTH_ORACLE, 60);
    }

    function test_setOracleID_Success(bytes32 id) external {
        address _token = makeAddr("random-token");

        vm.prank(OWNER);
        oracle.setOracleID(_token, id);

        assertEq(oracle.oracleID(_token), id);
    }

    function test_setOracleID_NotTheOwner(bytes32 id) external {
        address _token = makeAddr("random-token");

        vm.prank(BAD_ACTOR);
        vm.expectRevert("Ownable: caller is not the owner");
        oracle.setOracleID(_token, id);
    }

    function test_getTokenPrice_ExpLowerThanNormal(int8 _exp) external {
        int256 minExp = -32;
        int256 maxExp = -18;

        int256 safeExp = bound(_exp, minExp, maxExp); // _exp is now safely within range
        int32 _bndExp = int32(safeExp); // Now safe to cast
        int64 _price = 234520;

        PythStructs.Price memory _priceReturn =
            PythStructs.Price({price: _price, expo: _bndExp, conf: 10, publishTime: block.timestamp});

        console.log("test");
        vm.mockCall(PYTH_ORACLE, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector), abi.encode(_priceReturn));

        address _token = makeAddr("random-token");
        bytes32 _id = getRandomBytes32();

        vm.prank(OWNER);
        oracle.setOracleID(_token, _id);

        //Act
        uint256 _return = oracle.getTokenPrice(_token);

        assertEq(_return, uint256(int256(_price)) * 10 ** (uint32(int32(-_bndExp)) - 18));
    }

    function test_getTokenPrice_ExpGreaterThanNormal(int8 _exp) external {
        int256 minExp = -17;
        int256 maxExp = 0;

        int256 safeExp = bound(_exp, minExp, maxExp); // _exp is now safely within range
        int32 _bndExp = int32(safeExp); // Now safe to cast
        int64 _price = 234520;

        PythStructs.Price memory _priceReturn =
            PythStructs.Price({price: _price, expo: _bndExp, conf: 10, publishTime: block.timestamp});

        vm.mockCall(PYTH_ORACLE, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector), abi.encode(_priceReturn));

        address _token = makeAddr("random-token");
        bytes32 _id = getRandomBytes32();

        vm.prank(OWNER);
        oracle.setOracleID(_token, _id);

        //Act
        uint256 _return = oracle.getTokenPrice(_token);

        assertEq(_return, uint256(int256(_price)) * 10 ** (18 - uint32(int32(-_bndExp))));
    }

    function test_getTokenPrice_OracleNotSet() external {
        address _token = makeAddr("random-token");

        vm.expectRevert(abi.encodeWithSelector(IPriceOracle.OracleNotExist.selector, _token));
        oracle.getTokenPrice(_token);
    }

    function test_getTokenPrice_PriceLowerThanZero(int8 _exp) external {
        int256 minExp = -17;
        int256 maxExp = 0;

        int256 safeExp = bound(_exp, minExp, maxExp); // _exp is now safely within range
        int32 _bndExp = int32(safeExp); // Now safe to cast
        int64 _price = -1;

        PythStructs.Price memory _priceReturn =
            PythStructs.Price({price: _price, expo: _bndExp, conf: 10, publishTime: block.timestamp});

        vm.mockCall(PYTH_ORACLE, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector), abi.encode(_priceReturn));

        address _token = makeAddr("random-token");
        bytes32 _id = getRandomBytes32();

        vm.prank(OWNER);
        oracle.setOracleID(_token, _id);

        vm.expectRevert(abi.encodeWithSelector(IPriceOracle.NegativePriceNotAllowed.selector));
        oracle.getTokenPrice(_token);
    }

    function test_getTokenPrice_OracleWithNoStalePrice() external {
        MockPythReverting revertOracle = new MockPythReverting();
        vm.prank(OWNER);
        oracle = new PriceOracle(OWNER, address(revertOracle), 60);

        int64 _price = 1;

        PythStructs.Price memory _priceReturn =
            PythStructs.Price({price: _price, expo: -18, conf: 10, publishTime: block.timestamp});

        address _token = makeAddr("random-token");
        bytes32 _id = getRandomBytes32();

        vm.prank(OWNER);
        oracle.setOracleID(_token, _id);

        uint256 priecReturn = oracle.getTokenPrice(_token);

        assertEq(priecReturn, 0);
    }

    function getRandomBytes32() public view returns (bytes32) {
        return keccak256(abi.encodePacked(block.timestamp, msg.sender, block.prevrandao));
    }
}
