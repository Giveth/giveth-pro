// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import './proStakingTest.t.sol';

contract TestTransfers is ProStakingTest {
    function setUp() public override {
        super.setUp();
        console.log('upgrade price is', upgradePrice);
        vm.startPrank(stakerOne);
        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(1);
        assertEq(proStaking.balanceOf(stakerOne, 1), 1);
        vm.stopPrank();
    }

    function testTransfer() public {
        vm.startPrank(stakerOne);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit TransferDeposit(address(stakerOne), address(stakerTwo), 1, upgradePrice);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit RemoveStake(address(stakerOne), 1);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit AddStake(address(stakerTwo), 1);

        proStaking.transferDeposit(stakerTwo, 1);

        // check that the balances are correctly transferred
        assertEq(proStaking.balanceOf(stakerOne, 1), 0);
        assertEq(proStaking.balanceOf(stakerTwo, 1), 1);
        // check that the deposit amount eligible to be withdrawn is correctly transferred
        assertEq(proStaking.depositInfo(1, stakerOne), 0);
        assertEq(proStaking.depositInfo(1, stakerTwo), upgradePrice);
    }

    function testRevertTransfer() public {
        // test transferring a token that hasn't been minted already
        vm.prank(stakerOne);

        vm.expectRevert(ProStaking.NoDepositExists.selector);
        proStaking.transferDeposit(stakerWithNoTokens, 2);

        // test transferring token to user that already has token matching tokenId
        vm.startPrank(stakerTwo);
        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(1);
        vm.expectRevert(ProStaking.RecipientAlreadyHasDeposit.selector);
        proStaking.transferDeposit(stakerOne, 1);
        vm.stopPrank();

        // test transfer to self
        vm.prank(stakerOne);
        vm.expectRevert(ProStaking.CannotTransferToSelf.selector);
        proStaking.transferDeposit(stakerOne, 1);
    }

    function testMultipleTransfers() public {
        // 1st transfer
        vm.prank(stakerOne);
        proStaking.transferDeposit(stakerTwo, 1);

        // 2nd transfer
        vm.prank(stakerTwo);
        proStaking.transferDeposit(stakerWithNoTokens, 1);
        // check that the balances are correctly transferred
        assertEq(proStaking.balanceOf(stakerTwo, 1), 0);
        assertEq(proStaking.balanceOf(stakerWithNoTokens, 1), 1);
        // check that the deposit amount eligible to be withdrawn is correctly transferred
        assertEq(proStaking.depositInfo(1, stakerTwo), 0);
        assertEq(proStaking.depositInfo(1, stakerWithNoTokens), upgradePrice);

        // 3rd transfer
        vm.prank(stakerWithNoTokens);
        proStaking.transferDeposit(stakerOne, 1);
        // check that the balances are correctly transferred
        assertEq(proStaking.balanceOf(stakerWithNoTokens, 1), 0);
        assertEq(proStaking.balanceOf(stakerOne, 1), 1);
        // check that the deposit amount eligible to be withdrawn is correctly transferred
        assertEq(proStaking.depositInfo(1, stakerWithNoTokens), 0);
        assertEq(proStaking.depositInfo(1, stakerOne), upgradePrice);
    }

    function testTransferWithRoundApplications() public {
        vm.startPrank(stakerOne);
        proStaking.applyForRound(1, 1);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit UnappliedForRound(address(stakerOne), 1, 1);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit AppliedForRound(address(stakerTwo), 1, 1);

        proStaking.transferDeposit(stakerTwo, 1);
        assertEq(proStaking.hasAppliedForRound(stakerTwo, 1, 1), true);
        assertEq(proStaking.hasAppliedForRound(stakerOne, 1, 1), false);
    }

    function testTransferWithMultipleRoundApplications() public {
        vm.startPrank(roundAdmin);
        roundManager.createRound('round two');
        roundManager.createRound('round three');
        vm.stopPrank();

        vm.startPrank(stakerOne);
        proStaking.applyForRound(1, 1);
        proStaking.applyForRound(1, 2);
        proStaking.applyForRound(1, 3);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit UnappliedForRound(address(stakerOne), 1, 1);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit AppliedForRound(address(stakerTwo), 1, 1);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit UnappliedForRound(address(stakerOne), 1, 2);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit AppliedForRound(address(stakerTwo), 1, 2);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit UnappliedForRound(address(stakerOne), 1, 3);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit AppliedForRound(address(stakerTwo), 1, 3);

        proStaking.transferDeposit(stakerTwo, 1);
        assertEq(proStaking.hasAppliedForRound(stakerTwo, 1, 1), true);
        assertEq(proStaking.hasAppliedForRound(stakerTwo, 1, 2), true);
        assertEq(proStaking.hasAppliedForRound(stakerTwo, 1, 3), true);
        assertEq(proStaking.hasAppliedForRound(stakerOne, 1, 1), false);
        assertEq(proStaking.hasAppliedForRound(stakerOne, 1, 2), false);
        assertEq(proStaking.hasAppliedForRound(stakerOne, 1, 3), false);
    }
}
