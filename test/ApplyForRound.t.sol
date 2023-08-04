// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import './proStakingTest.t.sol';

contract TestApplyForRound is ProStakingTest {
    uint256 projectTokenId = 1;
    uint256 roundThatDoesExist = 1;
    uint256 anotherRoundThatDoesExist = 2;
    uint256 roundThatDoesntExist = 3;

    function setUp() public override {
        super.setUp();
        console.log('upgrade price is', upgradePrice);
        vm.startPrank(stakerOne);
        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(1);
        vm.stopPrank();
    }

    function testApplyForRound() public {
        // get round info from round manager
        (uint256 roundId,, bool isRoundActive,) = roundManager.rounds(roundThatDoesExist);

        assertEq(isRoundActive, true);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit AppliedForRound(address(stakerOne), 1, roundId);

        vm.startPrank(stakerOne);
        proStaking.applyForRound(projectTokenId, roundId);

        assertEq(proStaking.hasAppliedForRound(stakerOne, projectTokenId, roundId), true);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit UnappliedForRound(address(stakerOne), 1, roundId);

        proStaking.unapplyForRound(projectTokenId, roundId);

        vm.stopPrank();
    }

    function testRevertAlreadyAppliedForRound() public {
        vm.startPrank(stakerOne);
        proStaking.applyForRound(1, roundThatDoesExist);
        bool hasAppliedForRound = proStaking.hasAppliedForRound(stakerOne, projectTokenId, roundThatDoesExist);
        assertEq(hasAppliedForRound, true);

        vm.expectRevert(abi.encodeWithSelector(ProStaking.AlreadyAppliedForRound.selector, roundThatDoesExist));
        proStaking.applyForRound(1, roundThatDoesExist);
        vm.stopPrank();
    }

    function testRevertApplyRoundDoesntExist() public {
        vm.startPrank(stakerOne);
        vm.expectRevert(abi.encodeWithSelector(ProStaking.RoundNotActive.selector, roundThatDoesntExist));
        proStaking.applyForRound(projectTokenId, roundThatDoesntExist);
        vm.stopPrank();
    }

    function testApplyWithNoDeposit() public {
        assertEq(proStaking.balanceOf(stakerTwo, projectTokenId), 0);
        vm.startPrank(stakerTwo);
        vm.expectRevert(ProStaking.NoDepositExists.selector);
        proStaking.applyForRound(projectTokenId, roundThatDoesExist);
        vm.stopPrank();
    }

    function testApplyForRoundNotActive() public {
        vm.prank(roundAdmin);
        roundManager.deactivateRound(roundThatDoesExist);

        vm.startPrank(stakerOne);
        vm.expectRevert(abi.encodeWithSelector(ProStaking.RoundNotActive.selector, roundThatDoesntExist));
        proStaking.applyForRound(projectTokenId, roundThatDoesntExist);
        vm.stopPrank();
    }
}
