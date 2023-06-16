// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '../src/proStaking.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import "./interfaces/IERC20Bridged.sol";

contract ProStakingTest is Test {
    using SafeERC20 for IERC20;
   

        address omniBridge = 0xf6A78083ca3e2a662D6dd1703c939c8aCE2e268d;
    address givTokenAddress = 0x4f4F9b8D5B4d0Dc10506e5551B0513B61fD59e75;
    ProStaking implementation;
    ProStaking proStaking;
    ProxyAdmin proxyAdmin;
    TransparentUpgradeableProxy proxy;
    IERC20Bridged givToken;
    uint256 upgradePrice = 1 ether;
    address givethMultisig = address(0);
    address sender = address(1);

    constructor() {
         uint256 forkId = 
            vm.createFork('https://rpc.gnosis.gateway.fm');
        vm.selectFork(forkId);
    }

    function setUp() public {
        givToken =  IERC20Bridged(address(givTokenAddress));
        proxyAdmin = new ProxyAdmin();
        implementation = new ProStaking();
        proxy =
        new TransparentUpgradeableProxy(address(implementation), address(proxyAdmin), abi.encodeWithSelector(ProStaking(proStaking).initialize.selector, givToken, upgradePrice, givethMultisig ));
        proStaking = ProStaking(address(proxy));
        
        vm.prank(omniBridge);
            givToken.mint(sender, 100 ether);


    }
}
