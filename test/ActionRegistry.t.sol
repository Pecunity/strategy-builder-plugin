// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {ActionRegistry} from "contracts/ActionRegistry.sol";
import {IActionRegistry} from "contracts/interfaces/IActionRegistry.sol";

contract ActionRegistryTest is Test {
    ActionRegistry registry;
    address owner = makeAddr("owner");
    address nonOwner = makeAddr("no-owner");
    address action1 = makeAddr("action1");
    address action2 = makeAddr("action2");

    function setUp() public {
        vm.prank(owner);
        registry = new ActionRegistry();
    }

    function test_allowAction_Success() public {
        vm.prank(owner);
        registry.allowAction(action1);
        bool allowed = registry.isAllowed(action1);
        assertTrue(allowed, "Action should be allowed");
    }

    function test_allowAction_RevertAllowZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(IActionRegistry.ZeroAddressNotValid.selector);
        registry.allowAction(address(0));
    }

    function test_revokeAction_Success() public {
        vm.startPrank(owner);
        registry.allowAction(action1);
        registry.revokeAction(action1);
        vm.stopPrank();

        bool allowed = registry.isAllowed(action1);
        assertFalse(allowed, "Action should have been revoked");
    }

    function test_revokeAction_RevertRevokeUnregistered() public {
        vm.prank(owner);
        vm.expectRevert(IActionRegistry.ActionNotRegistered.selector);
        registry.revokeAction(action2);
    }

    function test_allowAction_OnlyOwnerCanAllow() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(nonOwner);
        registry.allowAction(action1);
    }

    function test_revokeAction_OnlyOwnerCanRevoke() public {
        vm.startPrank(owner);
        registry.allowAction(action1);
        vm.stopPrank();

        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        registry.revokeAction(action1);
    }
}
