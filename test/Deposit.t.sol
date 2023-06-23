// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import './proStakingTest.t.sol';

contract TestDeposit is ProStakingTest {

    function setUp() public override {
        super.setUp();
        console.log("upgrade price is", upgradePrice);
    }

    function testDeposit(uint256 tokenId) public {
        vm.assume(tokenId > 0);
        vm.startPrank(stakerOne);
        vm.expectEmit(true,true,true,true, address(givToken));
        emit Approval(address(stakerOne), address(proStaking), upgradePrice);

        vm.expectEmit(true,true,true,true, address(givToken));
        emit Transfer(address(stakerOne), address(proStaking), upgradePrice);

        vm.expectEmit(true,true,true,true, address(proStaking));
        emit TransferSingle(address(stakerOne), address(0), address(stakerOne), tokenId, 1);

        vm.expectEmit(true, true, true, true, address(proStaking));
        emit Deposit(address(stakerOne), tokenId, upgradePrice);

        vm.expectEmit(true,true,true,true, address(proStaking));
        emit AddStake(address(stakerOne), tokenId);
        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(tokenId);

        assertEq(proStaking.totalSupply(tokenId), 1);
        assertEq(givToken.balanceOf(address(proStaking)), upgradePrice);


        givToken.approve(address(proStaking), upgradePrice);
        // single user cannot have more than one of a given tokenId
        vm.expectRevert(ProStaking.RecipientAlreadyHasDeposit.selector);
        proStaking.depositAndMint(tokenId);

        // multiple users can have 1 token of the same tokenId
        vm.stopPrank();
        vm.startPrank(stakerTwo);
        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(tokenId);

        assertEq(proStaking.totalSupply(tokenId), 2);
        assertEq(givToken.balanceOf(address(proStaking)), upgradePrice * 2);

    }

    function testDepositMultiple() public {
        uint256 idOne = 1;
        uint256 idTwo = 2;
        uint256 idThree = 3;
        uint256 idFour = 4;
        uint256 idFive = 5;

        vm.startPrank(stakerOne);
        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(idOne);

        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(idTwo);

        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(idThree);
         vm.stopPrank();

        assertEq(proStaking.totalSupply(idOne), 1);
        assertEq(proStaking.totalSupply(idTwo), 1);
        assertEq(proStaking.totalSupply(idThree), 1);

        vm.startPrank(stakerTwo);
        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(idFour);

        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(idFive);

        assertEq(proStaking.totalSupply(idFour), 1);
        assertEq(proStaking.totalSupply(idFive), 1);

        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(idOne);

        assertEq(proStaking.totalSupply(idOne), 2);
    }

    function testFailDepositNoBalance() public {

        vm.startPrank(stakerWithNoTokens);
        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(1);
        vm.stopPrank();
    }

    function testUpgradePrice(uint256 amount) public {
        amount = bound(amount, 1, MAX_GIV_BALANCE);
        vm.prank(deployer);
        proStaking.setPrice(amount);

        vm.prank(omniBridge);
        givToken.mint(stakerOne, amount);

        vm.startPrank(stakerOne);
        givToken.approve(address(proStaking), amount);
        proStaking.depositAndMint(1);
    }


}
