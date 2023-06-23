// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import './proStakingTest.t.sol';

contract TestBalances is ProStakingTest {

    function setUp() public override {
        super.setUp();
        console.log("upgrade price is", upgradePrice);
    }

   function testDepositAndWithdrawalBalances() public {
        vm.startPrank(stakerOne);

        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(1);

        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(2);


        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(3);

        assertEq(givToken.balanceOf(address(proStaking)), upgradePrice * 3);
        assertEq(givToken.balanceOf(address(stakerOne)), intialMintAmount - upgradePrice * 3);
        assertEq(proStaking.balanceOf(stakerOne, 1), 1);
        assertEq(proStaking.balanceOf(stakerOne, 2), 1);
        assertEq(proStaking.balanceOf(stakerOne, 3), 1);

        proStaking.withdrawAndBurn(1);
        assertEq(givToken.balanceOf(address(proStaking)), upgradePrice * 2);
        assertEq(givToken.balanceOf(address(stakerOne)), intialMintAmount - upgradePrice * 2);

        proStaking.withdrawAndBurn(2);
        assertEq(givToken.balanceOf(address(proStaking)), upgradePrice);
        assertEq(givToken.balanceOf(address(stakerOne)), intialMintAmount - upgradePrice);

        proStaking.withdrawAndBurn(3);
        assertEq(givToken.balanceOf(address(proStaking)), 0);
        assertEq(givToken.balanceOf(address(stakerOne)), intialMintAmount);
        assertEq(proStaking.balanceOf(stakerOne, 1), 0);
        assertEq(proStaking.balanceOf(stakerOne, 2), 0);
        assertEq(proStaking.balanceOf(stakerOne, 3), 0);
   }

    function testBalanceOnPriceChange() public {
        uint256 oldUpgradePrice = proStaking.upgradePrice();
        uint256 newUpgradePrice = 5 ether;
        // start with user with balance of 0 GIV tokens for simplicity in testing
        assertEq(givToken.balanceOf(stakerWithNoTokens), 0);

        // mint exact tokens needed for depositing 
        vm.prank(omniBridge);
        givToken.mint(stakerWithNoTokens, oldUpgradePrice + newUpgradePrice);

        vm.startPrank(stakerWithNoTokens);

        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(1);
        vm.stopPrank();

        // change the price
        vm.prank(deployer);
        proStaking.setPrice(newUpgradePrice);

        vm.startPrank(stakerWithNoTokens);
        givToken.approve(address(proStaking), newUpgradePrice);
        proStaking.depositAndMint(2);


        // check the sum of the tokens held by the contract is accurate
        assertEq(givToken.balanceOf(address(proStaking)), oldUpgradePrice + newUpgradePrice);

        // check GIV token balance of staker and contract
        proStaking.withdrawAndBurn(2);
        console.log("giv token balance of staker", givToken.balanceOf(address(stakerWithNoTokens)));
        console.log("giv token balance of contract", givToken.balanceOf(address(proStaking)));
        assertEq(givToken.balanceOf(address(proStaking)), oldUpgradePrice);
        assertEq(givToken.balanceOf(address(stakerWithNoTokens)), newUpgradePrice);

        proStaking.withdrawAndBurn(1);

        assertEq(givToken.balanceOf(address(proStaking)), 0);
        assertEq(givToken.balanceOf(address(stakerWithNoTokens)), oldUpgradePrice + newUpgradePrice);

    }


    function testBalanceOnTransferAndWithdraw() public {
        vm.startPrank(stakerOne);
        givToken.approve(address(proStaking), upgradePrice);
        proStaking.depositAndMint(1);

        proStaking.transferDeposit(stakerTwo, 1);

        vm.stopPrank();
        
        // ensure the nft balance has transferred to staker two
        assertEq(proStaking.depositInfo(1, stakerOne), 0);
        assertEq(proStaking.depositInfo(1, stakerTwo), upgradePrice);
        vm.prank(stakerTwo);
        
        proStaking.withdrawAndBurn(1);

        // check staker one has less the balance of the upgrade price 
        // and staker two has the balance of the upgrade price + intial mint amount
        assertEq(givToken.balanceOf(address(proStaking)), 0);
        assertEq(givToken.balanceOf(address(stakerOne)), intialMintAmount - upgradePrice);
        assertEq(givToken.balanceOf(address(stakerTwo)), intialMintAmount + upgradePrice);

        // ensure the nft is burned for both accounts
        assertEq(proStaking.balanceOf(stakerOne, 1), 0);
        assertEq(proStaking.balanceOf(stakerTwo, 1), 0);
    }
}