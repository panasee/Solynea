// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Solynea} from "../src/Solynea.sol";
import {TokenConfig} from "../src/TokenConfig.sol";

contract SolyneaTest is Test {
    Solynea internal token;
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal nextOwner = makeAddr("nextOwner");
    uint256 internal constant INITIAL_SUPPLY = 1_000 ether;

    function setUp() public {
        token = new Solynea(TokenConfig.NAME, TokenConfig.SYMBOL, TokenConfig.DECIMALS, owner, INITIAL_SUPPLY);
    }

    function test_InitialDeployment() public view {
        assertEq(token.owner(), owner);
        assertEq(token.pendingOwner(), address(0));
        assertFalse(token.paused());
        assertEq(token.name(), "Solynea");
        assertEq(token.symbol(), "SLN");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_ZeroInitialSupply() public {
        Solynea empty = new Solynea("Solynea", "SLN", 18, owner, 0);
        assertEq(empty.totalSupply(), 0);
        assertEq(empty.balanceOf(owner), 0);
    }

    function test_ConfigurableMetadata() public {
        Solynea custom = new Solynea("Friends", "FRN", 6, owner, 12_000_000);
        assertEq(custom.name(), "Friends");
        assertEq(custom.symbol(), "FRN");
        assertEq(custom.decimals(), 6);
        assertEq(custom.totalSupply(), 12_000_000);
    }

    function test_ZeroOwnerRejected() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new Solynea("Solynea", "SLN", 18, address(0), 0);
    }

    function test_TransferBetweenOrdinaryHolders() public {
        vm.prank(owner);
        assertTrue(token.transfer(alice, 100 ether));
        vm.prank(alice);
        assertTrue(token.transfer(bob, 25 ether));
        assertEq(token.balanceOf(owner), 900 ether);
        assertEq(token.balanceOf(alice), 75 ether);
        assertEq(token.balanceOf(bob), 25 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function test_ApproveAndTransferFrom() public {
        vm.prank(owner);
        token.transfer(alice, 100 ether);
        vm.prank(alice);
        assertTrue(token.approve(bob, 40 ether));
        assertEq(token.allowance(alice, bob), 40 ether);
        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, 15 ether));
        assertEq(token.allowance(alice, bob), 25 ether);
        assertEq(token.balanceOf(alice), 85 ether);
        assertEq(token.balanceOf(bob), 15 ether);
    }

    function test_TransferWithoutAllowanceFails() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, 0, 1));
        vm.prank(bob);
        token.transferFrom(owner, bob, 1);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }

    function test_TransferAboveBalanceFails() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1));
        vm.prank(alice);
        token.transfer(bob, 1);
    }

    function test_TransferToZeroAddressFails() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(owner);
        token.transfer(address(0), 1);
    }

    function test_OwnerMint() public {
        vm.prank(owner);
        token.mint(alice, 123 ether);
        assertEq(token.balanceOf(alice), 123 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + 123 ether);
    }

    function test_NonOwnerMintFails() public {
        expectUnauthorized(alice);
        vm.prank(alice);
        token.mint(alice, 1 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function test_MintToZeroAddressFails() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(owner);
        token.mint(address(0), 1);
    }

    function test_HolderBurn() public {
        vm.prank(owner);
        token.transfer(alice, 100 ether);
        vm.prank(alice);
        token.burn(30 ether);
        assertEq(token.balanceOf(alice), 70 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - 30 ether);
    }

    function test_BurnAboveBalanceFails() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1));
        vm.prank(alice);
        token.burn(1);
    }

    function test_BurnFromRequiresAndConsumesAllowance() public {
        vm.prank(owner);
        token.transfer(alice, 100 ether);
        vm.prank(alice);
        token.approve(bob, 30 ether);
        vm.prank(bob);
        token.burnFrom(alice, 20 ether);
        assertEq(token.balanceOf(alice), 80 ether);
        assertEq(token.allowance(alice, bob), 10 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - 20 ether);
    }

    function test_OwnerCannotBurnOthersWithoutApproval() public {
        vm.prank(owner);
        token.transfer(alice, 100 ether);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, owner, 0, 1 ether));
        vm.prank(owner);
        token.burnFrom(alice, 1 ether);
        assertEq(token.balanceOf(alice), 100 ether);
    }

    function test_PausedTransferFails() public {
        vm.prank(owner);
        token.transfer(alice, 100 ether);
        pauseToken();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(alice);
        token.transfer(bob, 1 ether);
        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_PausedTransferFromFailsAndPreservesAllowance() public {
        vm.prank(owner);
        token.approve(bob, 10 ether);
        pauseToken();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(bob);
        token.transferFrom(owner, bob, 1 ether);
        assertEq(token.allowance(owner, bob), 10 ether);
    }

    function test_PausedMintFails() public {
        pauseToken();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(owner);
        token.mint(alice, 1 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function test_PausedBurnFails() public {
        pauseToken();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(owner);
        token.burn(1 ether);
    }

    function test_PausedBurnFromFailsAndPreservesAllowance() public {
        vm.prank(owner);
        token.approve(bob, 10 ether);
        pauseToken();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(bob);
        token.burnFrom(owner, 1 ether);
        assertEq(token.allowance(owner, bob), 10 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function test_ApproveStillWorksWhilePaused() public {
        pauseToken();
        vm.prank(owner);
        assertTrue(token.approve(bob, 10 ether));
        assertEq(token.allowance(owner, bob), 10 ether);
    }

    function test_UnpauseRestoresTransfer() public {
        pauseToken();
        vm.prank(owner);
        token.unpause();
        assertFalse(token.paused());
        vm.prank(owner);
        assertTrue(token.transfer(alice, 20 ether));
        assertEq(token.balanceOf(alice), 20 ether);
    }

    function test_NonOwnerPauseFails() public {
        expectUnauthorized(alice);
        vm.prank(alice);
        token.pause();
        assertFalse(token.paused());
    }

    function test_NonOwnerUnpauseFails() public {
        pauseToken();
        expectUnauthorized(alice);
        vm.prank(alice);
        token.unpause();
        assertTrue(token.paused());
    }

    function test_TwoStepOwnershipTransfer() public {
        vm.prank(owner);
        token.transferOwnership(nextOwner);
        assertEq(token.owner(), owner);
        assertEq(token.pendingOwner(), nextOwner);
        expectUnauthorized(nextOwner);
        vm.prank(nextOwner);
        token.mint(alice, 1 ether);
        vm.prank(nextOwner);
        token.acceptOwnership();
        assertEq(token.owner(), nextOwner);
        assertEq(token.pendingOwner(), address(0));
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }

    function test_OnlyPendingOwnerCanAccept() public {
        vm.prank(owner);
        token.transferOwnership(nextOwner);
        expectUnauthorized(alice);
        vm.prank(alice);
        token.acceptOwnership();
    }

    function test_NonOwnerCannotTransferOwnership() public {
        expectUnauthorized(alice);
        vm.prank(alice);
        token.transferOwnership(alice);
    }

    function test_NewOwnerCanMintPauseAndUnpause() public {
        transferOwnership();
        vm.startPrank(nextOwner);
        token.mint(alice, 10 ether);
        token.pause();
        assertTrue(token.paused());
        token.unpause();
        vm.stopPrank();
        assertFalse(token.paused());
        assertEq(token.balanceOf(alice), 10 ether);
    }

    function test_OldOwnerLosesAllAdminPrivileges() public {
        transferOwnership();
        expectUnauthorized(owner);
        vm.prank(owner);
        token.mint(alice, 1);
        expectUnauthorized(owner);
        vm.prank(owner);
        token.pause();
        vm.prank(nextOwner);
        token.pause();
        expectUnauthorized(owner);
        vm.prank(owner);
        token.unpause();
        expectUnauthorized(owner);
        vm.prank(owner);
        token.transferOwnership(owner);
        expectUnauthorized(owner);
        vm.prank(owner);
        token.renounceOwnership();
    }

    function test_OldOwnerStillCanUseOwnTokens() public {
        transferOwnership();
        vm.startPrank(owner);
        token.transfer(alice, 10 ether);
        token.burn(5 ether);
        vm.stopPrank();
        assertEq(token.balanceOf(owner), 985 ether);
    }

    function test_CancelPendingOwnershipTransfer() public {
        vm.startPrank(owner);
        token.transferOwnership(nextOwner);
        token.transferOwnership(address(0));
        vm.stopPrank();
        assertEq(token.owner(), owner);
        assertEq(token.pendingOwner(), address(0));
        expectUnauthorized(nextOwner);
        vm.prank(nextOwner);
        token.acceptOwnership();
    }

    function test_RenounceOwnershipIsPermanentButTransfersContinue() public {
        vm.prank(owner);
        token.renounceOwnership();
        assertEq(token.owner(), address(0));
        expectUnauthorized(owner);
        vm.prank(owner);
        token.mint(alice, 1);
        vm.prank(owner);
        token.transfer(alice, 10 ether);
        assertEq(token.balanceOf(alice), 10 ether);
    }

    function test_RenounceWhilePausedLeavesTokenPermanentlyPaused() public {
        pauseToken();
        vm.prank(owner);
        token.renounceOwnership();
        expectUnauthorized(owner);
        vm.prank(owner);
        token.unpause();
        assertTrue(token.paused());
    }

    function testFuzz_TransferPreservesSupply(uint256 amount) public {
        amount = bound(amount, 0, INITIAL_SUPPLY);
        vm.prank(owner);
        token.transfer(alice, amount);
        assertEq(token.balanceOf(owner) + token.balanceOf(alice), INITIAL_SUPPLY);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function testFuzz_MintAndBurnAccountForRawUnits(uint256 amount, uint256 burned) public {
        amount = bound(amount, 0, type(uint256).max - INITIAL_SUPPLY);
        burned = bound(burned, 0, amount);
        vm.prank(owner);
        token.mint(alice, amount);
        vm.prank(alice);
        token.burn(burned);
        assertEq(token.balanceOf(alice), amount - burned);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + (amount - burned));
    }

    function expectUnauthorized(address account) internal {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, account));
    }

    function pauseToken() internal {
        vm.prank(owner);
        token.pause();
        assertTrue(token.paused());
    }

    function transferOwnership() internal {
        vm.prank(owner);
        token.transferOwnership(nextOwner);
        vm.prank(nextOwner);
        token.acceptOwnership();
    }
}
