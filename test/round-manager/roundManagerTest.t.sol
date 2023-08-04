// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '../../src/roundManager.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import '../interfaces/IERC20Bridged.sol';

contract RoundManagerTest is Test {
    RoundManager implementation;
    RoundManager roundManager;
    ProxyAdmin proxyAdmin;
    TransparentUpgradeableProxy proxy;
    uint8 maxActiveRounds = 10;

    event RoundCreated(uint256 roundId, string roundName);
    event RoundLocked(uint256 roundId);
    event RoundUnlocked(uint256 roundId);
    event RoundDeleted(uint256 roundId, string roundName);
    event RoundActivated(uint256 roundId);
    event RoundDeactivated(uint256 roundId);

    address deployer = address(1);
    address roundAdmin = address(2);
    address givethMultisig = address(3);

    constructor() {}

    function setUp() public virtual {
        vm.startPrank(deployer);
        proxyAdmin = new ProxyAdmin();
        implementation = new RoundManager();
        proxy =
        new TransparentUpgradeableProxy(address(implementation), address(proxyAdmin), abi.encodeWithSelector(RoundManager(roundManager)
            .initialize.selector, maxActiveRounds));
        roundManager = RoundManager(address(proxy));
        roundManager.grantRole(roundManager.ROUND_MANAGER(), roundAdmin);
        vm.stopPrank();

        vm.label(deployer, 'deployer');
        vm.label(roundAdmin, 'roundAdmin');
        vm.label(address(roundManager), 'roundManager');
        vm.label(address(proxyAdmin), 'proxyAdmin');
        vm.label(address(givethMultisig), 'givethMultisig');
        vm.label(address(implementation), 'roundManagerImplementation');
        vm.label(address(proxy), 'roundManagerProxy');
    }

    function testCreateRound() public {
        vm.startPrank(roundAdmin);
        vm.expectEmit(true, true, true, true, address(roundManager));
        emit RoundCreated(1, 'round one');

        vm.expectEmit(true, true, true, true, address(roundManager));
        emit RoundActivated(1);

        roundManager.createRound('round one');

        (uint256 roundId, string memory roundName, bool isRoundActive, bool isWithdrawalsEnabled) =
            roundManager.rounds(1);
        assertEq(roundManager.roundsCreated(), 1);
        assertEq(roundManager.roundsActive(), 1);
        assertEq(roundId, 1);
        assertEq(roundName, 'round one');
        assertEq(isRoundActive, true);
        assertEq(isWithdrawalsEnabled, true);
    }

    function testRevertCreateRound() public {
        vm.startPrank(roundAdmin);
        console.log('this is the maximum number of rounds', roundManager.maxActiveRounds());

        roundManager.createRound('round one');
        roundManager.createRound('round two');
        roundManager.createRound('round three');
        roundManager.createRound('round four');
        roundManager.createRound('round five');
        roundManager.createRound('round six');
        roundManager.createRound('round seven');
        roundManager.createRound('round eight');
        roundManager.createRound('round nine');
        roundManager.createRound('round ten');

        vm.expectRevert(abi.encodeWithSelector(RoundManager.OverMaxRounds.selector, maxActiveRounds));
        roundManager.createRound('round eleven');
        vm.stopPrank();
    }

    function testActivateRound() public {
        vm.startPrank(roundAdmin);

        roundManager.createRound('round one');

        vm.expectEmit(true, true, true, true, address(roundManager));
        emit RoundDeactivated(1);

        roundManager.deactivateRound(1);

        (,, bool isRoundActive, bool isWithdrawalsEnabled) = roundManager.rounds(1);
        assertEq(isRoundActive, false);
        assertEq(isWithdrawalsEnabled, true);
        assertEq(roundManager.roundsActive(), 0);

        vm.expectEmit(true, true, true, true, address(roundManager));
        emit RoundActivated(1);

        roundManager.activateRound(1);

        (,, isRoundActive, isWithdrawalsEnabled) = roundManager.rounds(1);
        assertEq(isRoundActive, true);
        assertEq(isWithdrawalsEnabled, true);
        assertEq(roundManager.roundsActive(), 1);
    }

    function testGetActiveRounds() public {
        vm.startPrank(roundAdmin);

        roundManager.createRound('round one');
        roundManager.createRound('round two');
        roundManager.createRound('round three');
        roundManager.createRound('round four');
        roundManager.createRound('round five');

        uint256[] memory activeRounds = roundManager.getActiveRounds();
        assertEq(activeRounds.length, 5);
        assertEq(activeRounds[0], 1);
        assertEq(activeRounds[1], 2);
        assertEq(activeRounds[2], 3);
        assertEq(activeRounds[3], 4);
        assertEq(activeRounds[4], 5);

        roundManager.deactivateRound(2);
        activeRounds = roundManager.getActiveRounds();

        assertEq(activeRounds.length, 4);
        assertEq(activeRounds[0], 1);
        assertEq(activeRounds[1], 3);
        assertEq(activeRounds[2], 4);
        assertEq(activeRounds[3], 5);

        roundManager.createRound('round six');
        roundManager.deactivateRound(1);
        activeRounds = roundManager.getActiveRounds();

        assertEq(activeRounds.length, 4);
        assertEq(activeRounds[0], 3);
        assertEq(activeRounds[1], 4);
        assertEq(activeRounds[2], 5);
        assertEq(activeRounds[3], 6);
    }

    function testLockRound() public {
        vm.startPrank(roundAdmin);

        roundManager.createRound('round one');

        vm.expectEmit(true, true, true, true, address(roundManager));
        emit RoundLocked(1);

        roundManager.lockRound(1);
        (,, bool isRoundActive, bool isWithdrawalsEnabled) = roundManager.rounds(1);

        assertEq(isRoundActive, true);
        assertEq(isWithdrawalsEnabled, false);

        vm.expectEmit(true, true, true, true, address(roundManager));
        emit RoundUnlocked(1);

        roundManager.unlockRound(1);

        (,, isRoundActive, isWithdrawalsEnabled) = roundManager.rounds(1);

        assertEq(isRoundActive, true);
        assertEq(isWithdrawalsEnabled, true);
    }

    function testIfRoundExists() public {
        vm.startPrank(roundAdmin);

        roundManager.createRound('round one');
        roundManager.createRound('round two');

        vm.expectRevert(abi.encodeWithSelector(RoundManager.RoundDoesNotExist.selector, 3));
        roundManager.activateRound(3);

        vm.expectRevert(abi.encodeWithSelector(RoundManager.RoundDoesNotExist.selector, 3));
        roundManager.getRoundInfo(3);

        vm.expectRevert(abi.encodeWithSelector(RoundManager.RoundDoesNotExist.selector, 3));
        roundManager.renameAndActivateRound(3, 'other round 3');

        vm.expectRevert(abi.encodeWithSelector(RoundManager.RoundDoesNotExist.selector, 3));
        roundManager.lockRound(3);

        vm.expectRevert(abi.encodeWithSelector(RoundManager.RoundDoesNotExist.selector, 3));
        roundManager.unlockRound(3);

        vm.expectRevert(abi.encodeWithSelector(RoundManager.RoundDoesNotExist.selector, 3));
        roundManager.getRoundWithdrawalsEnabled(3);

        vm.expectRevert(abi.encodeWithSelector(RoundManager.RoundDoesNotExist.selector, 3));
        roundManager.deactivateRound(3);

        vm.expectRevert(abi.encodeWithSelector(RoundManager.RoundDoesNotExist.selector, 3));
        roundManager.renameRound(3, 'other round 3');
    }

    function testSetMaxRounds() public {
        vm.startPrank(roundAdmin);

        // verify that the maxActiveRounds matches the global variable at start
        assertEq(roundManager.maxActiveRounds(), maxActiveRounds);

        // verify that the maxActiveRounds can be changed
        roundManager.setMaxActiveRounds(2);
        assertEq(roundManager.maxActiveRounds(), 2);

        // create two rounds
        roundManager.createRound('round one');
        roundManager.createRound('round two');

        // expect revert making a third round
        vm.expectRevert(abi.encodeWithSelector(RoundManager.OverMaxRounds.selector, 2));
        roundManager.createRound('round three');

        // deactivate round one then create a third round, three rounds exist but only two are active now
        roundManager.deactivateRound(1);
        roundManager.createRound('round three');

        // expect revert activating round one, for a total of three active rounds
        vm.expectRevert(abi.encodeWithSelector(RoundManager.OverMaxRounds.selector, 2));
        roundManager.activateRound(1);

        // expect revert setting maxActiveRounds to less than the number of active rounds
        vm.expectRevert(abi.encodeWithSelector(RoundManager.MaxRoundsLessThanActiveRounds.selector, 1, 2));
        roundManager.setMaxActiveRounds(1);

        // set max active rounds to four
        roundManager.setMaxActiveRounds(4);
        assertEq(roundManager.maxActiveRounds(), 4);

        // create another round and activate round one, for a total of 4 active rounds
        roundManager.createRound('round four');
        roundManager.activateRound(1);
    }

    function testGetWithdrawalsEnabled() public {
        vm.startPrank(roundAdmin);

        roundManager.createRound('round one');
        assertEq(roundManager.getRoundWithdrawalsEnabled(1), true);

        roundManager.lockRound(1);
        assertEq(roundManager.getRoundWithdrawalsEnabled(1), false);

        roundManager.unlockRound(1);
        assertEq(roundManager.getRoundWithdrawalsEnabled(1), true);

        roundManager.deactivateRound(1);
        assertEq(roundManager.getRoundWithdrawalsEnabled(1), true);

        roundManager.activateRound(1);
        assertEq(roundManager.getRoundWithdrawalsEnabled(1), true);

        roundManager.deactivateRound(1);
        roundManager.renameAndActivateRound(1, 'other round one');
        assertEq(roundManager.getRoundWithdrawalsEnabled(1), true);
    }

    function testRenameRound() public {
        vm.startPrank(roundAdmin);

        // check that we can change the name successfully
        roundManager.createRound('round one');
        roundManager.renameRound(1, 'other round one');

        // verify the name had changed
        (, string memory name,,) = roundManager.rounds(1);
        assertEq(name, 'other round one');

        // verify that we can activate and change the name at the same time
        roundManager.deactivateRound(1);
        roundManager.renameAndActivateRound(1, 'round one again');
        (, name,,) = roundManager.rounds(1);
        assertEq(name, 'round one again');

        // throw an error if we try to change the name to a name that is too long
        bytes memory reallyLongRoundName = bytes('this is a really long round name that is longer than 32 characters');
        console.log(reallyLongRoundName.length);
        vm.expectRevert(abi.encodeWithSelector(RoundManager.RoundNameTooLong.selector, reallyLongRoundName.length, 32));
        roundManager.renameRound(1, string(reallyLongRoundName));

        // throw an error if we try to create a round with a name that is too long
        vm.expectRevert(abi.encodeWithSelector(RoundManager.RoundNameTooLong.selector, reallyLongRoundName.length, 32));
        roundManager.createRound(string(reallyLongRoundName));

        // deactivate round then throw error when we try to activate and rename with a name that is too long
        roundManager.deactivateRound(1);
        vm.expectRevert(abi.encodeWithSelector(RoundManager.RoundNameTooLong.selector, reallyLongRoundName.length, 32));
        roundManager.renameAndActivateRound(1, string(reallyLongRoundName));
    }
}
