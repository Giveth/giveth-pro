// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '../src/proStaking.sol';
import '../src/roundManager.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import './interfaces/IERC20Bridged.sol';

contract ProStakingTest is Test {
    uint256 public constant MAX_GIV_BALANCE = 10 ** 28; // 10 Billion, Total minted giv is 1B at the moment

    address omniBridge = 0xf6A78083ca3e2a662D6dd1703c939c8aCE2e268d;
    address givTokenAddress = 0x4f4F9b8D5B4d0Dc10506e5551B0513B61fD59e75;
    ProStaking implementation;
    ProStaking proStaking;
    ProxyAdmin proxyAdmin;
    TransparentUpgradeableProxy proxy;
    IERC20Bridged givToken;

    RoundManager roundManager;
    

    uint256 upgradePrice = 1 ether;
    uint256 intialMintAmount = 100 ether;
    address deployer = address(1);
    address givethMultisig = address(2);
    address stakerOne = address(3);
    address stakerTwo = address(4);
    address stakerWithNoTokens = address(5);

    event Deposit(address indexed account, uint256 indexed tokenId, uint256 amount);
    event Withdraw(address indexed account, uint256 indexed tokenId, uint256 amount);
    event Slash(address indexed account, uint256 indexed tokenId, uint256 amount);
    event AddStake(address indexed account, uint256 tokenId);
    event RemoveStake(address indexed account, uint256 tokenId);
    event TransferDeposit(address indexed from, address indexed to, uint256 indexed tokenId, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event TransferSingle(
        address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value
    );

    constructor() {
        uint256 forkId = vm.createFork('https://rpc.gnosis.gateway.fm');
        vm.selectFork(forkId);
    }

    function setUp() public virtual {
        vm.deal(deployer, intialMintAmount);
        vm.startPrank(deployer);
        givToken = IERC20Bridged(address(givTokenAddress));
        proxyAdmin = new ProxyAdmin();
        implementation = new ProStaking();
        proxy =
        new TransparentUpgradeableProxy(address(implementation), address(proxyAdmin), abi.encodeWithSelector(ProStaking(proStaking).initialize.selector, givToken, upgradePrice, givethMultisig ));
        proStaking = ProStaking(address(proxy));
        vm.stopPrank();

        vm.startPrank(omniBridge);
        givToken.mint(stakerOne, intialMintAmount);
        givToken.mint(stakerTwo, intialMintAmount);
        vm.stopPrank();

        vm.label(deployer, 'deployer');
        vm.label(stakerOne, 'stakerOne');
        vm.label(stakerTwo, 'stakerTwo');
        vm.label(address(givToken), 'givToken');
        vm.label(address(proStaking), 'proStaking');
        vm.label(address(proxyAdmin), 'proxyAdmin');
        vm.label(address(givethMultisig), 'givethMultisig');
        vm.label(address(implementation), 'proStakingImplementation');
        vm.label(address(proxy), 'proStakingProxy');
    }
}
