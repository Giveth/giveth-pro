// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import './proStakingTest.t.sol';

contract TestSlash is ProStakingTest {
    uint256 tokenId = 1;

    function setUp() public override {
        super.setUp();
        vm.startPrank(deployer);
        proStaking.setWithdrawalsEnabled(false);
        proStaking.grantRole(0x00, givethMultisig);
        console.log("upgrade price is", upgradePrice);
        vm.stopPrank();
         vm.startPrank(stakerOne);
        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(tokenId);
        assertEq(proStaking.balanceOf(stakerOne, tokenId), 1);
        vm.stopPrank();
    }

    function testSlash() public {
        vm.startPrank(givethMultisig);
        console.log("are withdrawals enabled?", proStaking.isWithdrawalsEnabled());
        
        // burn NFT
        vm.expectEmit(true,true,true,true, address(proStaking));
        emit TransferSingle(address(givethMultisig), address(stakerOne), address(0), 1, 1);

        // transfer GIV tokens to withdrawer
        vm.expectEmit(true,true,true,true, address(givToken));
        emit Transfer(address(proStaking), address(givethMultisig), upgradePrice);

        // remove stake from project (tokenId)
        vm.expectEmit(true,true,true,true, address(proStaking));
        emit RemoveStake(address(stakerOne), tokenId);

        // log withdrawal from contract
        vm.expectEmit(true,true,true,true, address(proStaking));
        emit Slash(address(stakerOne), tokenId, upgradePrice);

        proStaking.slash(tokenId, stakerOne);

        assertEq(proStaking.balanceOf(stakerOne, tokenId), 0);
        assertEq(proStaking.depositInfo(tokenId, stakerOne), 0);
        assertEq(givToken.balanceOf(address(givethMultisig)), upgradePrice);

    }

    function testDoubleSlashRevert() public {
        console.log("pro staking address is", address(proStaking));
        vm.startPrank(givethMultisig);
        // attempt to withdraw twice for the same token
        proStaking.slash(tokenId, stakerOne);

        vm.expectRevert(ProStaking.NoDepositExists.selector);
        proStaking.slash(tokenId, stakerOne);
        vm.stopPrank();

    }

    function testFailSlashNotAdmin() public {
        vm.startPrank(stakerTwo);
        proStaking.slash(tokenId, stakerOne);
    }


    function testTransferAndSlash() public {
        // transfer deposit to another user
        vm.prank(stakerOne);
        proStaking.transferDeposit(stakerTwo, tokenId);

        // slash despoit from admin
        vm.prank(givethMultisig);
        proStaking.slash(tokenId, stakerTwo);

        assertEq(proStaking.balanceOf(stakerTwo, tokenId), 0);
        assertEq(proStaking.depositInfo(tokenId, stakerTwo), 0);
        assertEq(givToken.balanceOf(address(givethMultisig)), upgradePrice);
    }

}