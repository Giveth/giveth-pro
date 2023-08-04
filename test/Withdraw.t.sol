// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import './proStakingTest.t.sol';

contract TestWithdrawals is ProStakingTest {
    uint256 tokenId = 1;

    function setUp() public override {
        super.setUp();
        vm.prank(deployer);
        proStaking.grantRole(0x00, givethMultisig);
        console.log('upgrade price is', upgradePrice);
        vm.startPrank(stakerOne);
        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(tokenId);
        assertEq(proStaking.balanceOf(stakerOne, tokenId), 1);
        vm.stopPrank();

        vm.prank(roundAdmin);
        roundManager.createRound('round two');
    }

    function testWithdraw() public {
        vm.startPrank(stakerOne);
        proStaking.applyForRound(tokenId, 1);
        proStaking.applyForRound(tokenId, 2);
        
        //console.log("are withdrawals enabled?", proStaking.isWithdrawalsEnabled());

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit UnappliedForRound(address(stakerOne), tokenId, 1);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit UnappliedForRound(address(stakerOne), tokenId, 2);
        // burn NFT
        vm.expectEmit(true, true, true, true, address(proStaking));
        emit TransferSingle(address(stakerOne), address(stakerOne), address(0), 1, 1);

        // transfer GIV tokens to withdrawer
        vm.expectEmit(true, true, true, true, address(givToken));
        emit Transfer(address(proStaking), address(stakerOne), upgradePrice);

        // remove stake from project (tokenId)
        vm.expectEmit(true, true, true, true, address(proStaking));
        emit RemoveStake(address(stakerOne), tokenId);

        // log withdrawal from contract
        vm.expectEmit(true, true, true, true, address(proStaking));
        emit Withdraw(address(stakerOne), tokenId, upgradePrice);


        proStaking.withdrawAndBurn(tokenId);

        assertEq(proStaking.balanceOf(stakerOne, tokenId), 0);
        assertEq(proStaking.depositInfo(tokenId, stakerOne), 0);
        assertEq(givToken.balanceOf(address(stakerOne)), intialMintAmount);
        assertEq(proStaking.hasAppliedForRound(stakerOne, tokenId, 1), false);
        assertEq(proStaking.hasAppliedForRound(stakerOne, tokenId, 2), false);
    }

    function testDoubleWithdrawRevert() public {
        vm.prank(stakerOne);
        // attempt to withdraw twice for the same token
        proStaking.withdrawAndBurn(tokenId);

        vm.expectRevert(ProStaking.NoDepositExists.selector);
        proStaking.withdrawAndBurn(tokenId);
    }

    function testRevertWithdraw(uint256 id) public {
        vm.assume(id != tokenId);
        vm.prank(stakerOne);

        // withdraw for a token that doesn't exist
        vm.expectRevert(ProStaking.NoDepositExists.selector);
        proStaking.withdrawAndBurn(id);

        // withdraw for a token that does exist but is not owned by the withdrawer
        vm.prank(stakerTwo);
        vm.expectRevert(ProStaking.NoDepositExists.selector);
        proStaking.withdrawAndBurn(tokenId);

        //     vm.prank(givethMultisig);
        //    //  proStaking.setWithdrawalsEnabled(false);

        //     // withdraw when withdrawals are disabled
        //     vm.prank(stakerOne);
        //     vm.expectRevert(ProStaking.WithdrawalsDisabled.selector);
        //     proStaking.withdrawAndBurn(tokenId);
    }

    function testTransferAndWithdraw() public {
        vm.startPrank(stakerOne);
        proStaking.transferDeposit(stakerTwo, tokenId);

        //attempt to withdraw deposit that has been transferred to new owners from old owner
        vm.expectRevert(ProStaking.NoDepositExists.selector);
        proStaking.withdrawAndBurn(tokenId);
    }

    function testWithdrawOnLockedRound() public {
        uint256 roundId = 1;
        vm.prank(roundAdmin);
        roundManager.lockRound(roundId);

        vm.startPrank(stakerOne);
        proStaking.applyForRound(tokenId, roundId);
        vm.expectRevert(abi.encodeWithSelector(ProStaking.RoundLocked.selector, roundId));
        proStaking.withdrawAndBurn(tokenId);
    }
}
