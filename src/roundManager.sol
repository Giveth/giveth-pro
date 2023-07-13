// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';

contract RoundManager is Initializable, AccessControlUpgradeable {
    bytes32 public constant ROUND_MANAGER = keccak256('ROUND_MANAGER');
    uint256 public roundsCreated;
    uint8 public roundsActive;

    // this is to prevent out of gas errors when checking if a round is active
    uint8 public maxActiveRounds;

    // this is to limit the length of round names for storage purposes
    uint8 private constant MAX_ROUND_NAME_LENGTH = 32;

    event RoundCreated(uint256 roundId, string roundName);
    event RoundLocked(uint256 roundId);
    event RoundUnlocked(uint256 roundId);
    event RoundDeleted(uint256 roundId, string roundName);
    event RoundActivated(uint256 roundId);
    event RoundDeactivated(uint256 roundId);

    error RoundNameTooLong(uint256 roundNameLength, uint16 maxRoundNameLength);
    error OverMaxRounds(uint8 maxRounds);
    error RoundDoesNotExist(uint256 roundId);
    error RoundIsNotActive(uint256 roundId);
    // error RoundIsNotActive(uint256 roundId);
    error RoundIsAlreadyActive(uint256 roundId);
    error MaxRoundsLessThanActiveRounds(uint8 maxRounds, uint8 activeRounds);

    struct Round {
        uint256 roundId;
        string roundName;
        bool isRoundActive;
        bool isWithdrawalsEnabled;
    }

    mapping(uint256 => Round) public rounds;

    constructor() {
        _disableInitializers();
    }

    function initialize(uint8 _maxActiveRounds) public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ROUND_MANAGER, msg.sender);
        roundsCreated = 0;
        roundsActive = 0;
        maxActiveRounds = _maxActiveRounds;
    }

    modifier _checkNameLength(string memory _roundName) {
        bytes memory b = bytes(_roundName);
        if (b.length > MAX_ROUND_NAME_LENGTH) revert RoundNameTooLong(b.length, MAX_ROUND_NAME_LENGTH);
        _;
    }

    modifier _checkRoundExists(uint256 _roundId) {
        if (rounds[_roundId].roundId == 0) revert RoundDoesNotExist(_roundId);
        _;
    }

    /// create a new round to be tracked, automatically sets the round to active and withdrawals enabled
    /// @param _roundName the name of the round max 32 characters
    function createRound(string memory _roundName) public onlyRole(ROUND_MANAGER) _checkNameLength(_roundName) {
        if (roundsActive >= maxActiveRounds) revert OverMaxRounds(maxActiveRounds);
        roundsCreated++;
        roundsActive++;
        Round memory newRound = Round(roundsCreated, _roundName, true, true);
        rounds[roundsCreated] = newRound;
        emit RoundCreated(roundsCreated, _roundName);
        emit RoundActivated(roundsCreated);
    }

    /// disable a round, this will prevent users from applying for the round and will prevent withdrawals
    /// @param _roundId the id of the round to disable
    function deactivateRound(uint256 _roundId) public onlyRole(ROUND_MANAGER) _checkRoundExists(_roundId) {
        rounds[_roundId].isRoundActive = false;
        rounds[_roundId].isWithdrawalsEnabled = true;
        roundsActive--;
        emit RoundDeactivated(_roundId);
    }

    /// enable a round, this will allow users to apply for the round and will allow withdrawals
    /// @param _roundId the id of the round to enable
    function activateRound(uint256 _roundId) public onlyRole(ROUND_MANAGER) _checkRoundExists(_roundId) {
        if (roundsActive >= maxActiveRounds) revert OverMaxRounds(maxActiveRounds);
        if (rounds[_roundId].isRoundActive == true) revert RoundIsAlreadyActive(_roundId);
        rounds[_roundId].isRoundActive = true;
        rounds[_roundId].isWithdrawalsEnabled = true;
        roundsActive++;
        emit RoundUnlocked(_roundId);
        emit RoundActivated(_roundId);
    }

    /// disable withdrawals and applications for a round, this will prevent users from withdrawing from the round
    /// @param _roundId the id of the round to disable withdrawals for
    function lockRound(uint256 _roundId) public onlyRole(ROUND_MANAGER) _checkRoundExists(_roundId) {
        if (rounds[_roundId].isRoundActive == false) revert RoundIsNotActive(_roundId);
        rounds[_roundId].isWithdrawalsEnabled = false;
        emit RoundLocked(_roundId);
    }

    /// enable withdrawals and applications for a round, this will allow users to withdraw from the round
    /// @param _roundId the id of the round to enable withdrawals for
    function unlockRound(uint256 _roundId) public onlyRole(ROUND_MANAGER) _checkRoundExists(_roundId) {
        rounds[_roundId].isWithdrawalsEnabled = true;
        emit RoundUnlocked(_roundId);
    }

    function renameRound(uint256 _roundId, string memory _newRoundName)
        public
        onlyRole(ROUND_MANAGER)
        _checkNameLength(_newRoundName)
        _checkRoundExists(_roundId)
    {
        rounds[_roundId].roundName = _newRoundName;
    }

    function renameAndActivateRound(uint256 _roundId, string memory _newRoundName)
        public
        _checkRoundExists(_roundId)
        onlyRole(ROUND_MANAGER)
        _checkNameLength(_newRoundName)
    {
        if (rounds[_roundId].isRoundActive == true) revert RoundIsAlreadyActive(_roundId);
        if (roundsActive >= maxActiveRounds) revert OverMaxRounds(maxActiveRounds);
        roundsActive++;
        rounds[_roundId].roundName = _newRoundName;
        rounds[_roundId].isRoundActive = true;
        rounds[_roundId].isWithdrawalsEnabled = true;
        emit RoundUnlocked(_roundId);
        emit RoundActivated(_roundId);
    }
    // /// delete a round, this will remove all data for the round
    // /// @param _roundId the id of the round to delete
    // function deleteRound(uint256 _roundId) public _checkRoundExists(_roundId) onlyRole(ROUND_MANAGER) {
    //     delete rounds[_roundId];
    //     roundsCreated--;
    //     emit RoundDeleted(_roundId, rounds[_roundId].roundName);
    // }

    /// set a max number of rounds, this is to prevent out of gas errors when checking if a round is active
    /// @param _maxRounds the max number of rounds
    function setMaxActiveRounds(uint8 _maxRounds) public onlyRole(ROUND_MANAGER) {
        if (_maxRounds < roundsActive) revert MaxRoundsLessThanActiveRounds(_maxRounds, roundsActive);
        maxActiveRounds = _maxRounds;
    }

    /// get active rounds
    /// @return activeRounds an array of active round ids
    function getActiveRounds() public view returns (uint256[] memory activeRounds) {
        uint256[] memory _activeRounds = new uint256[](roundsCreated);
        uint256 activeRoundCount = 0;
        for (uint256 i = 1; i <= roundsCreated; i++) {
            if (rounds[i].isRoundActive) {
                _activeRounds[activeRoundCount] = rounds[i].roundId;
                activeRoundCount++;
            }
        }
        activeRounds = new uint256[](activeRoundCount);
        for (uint256 i = 0; i < activeRoundCount; i++) {
            activeRounds[i] = _activeRounds[i];
        }
    }

    /// get round info
    /// @param _roundId the id of the round to get info for
    /// @return roundId the id of the round
    /// @return roundName the name of the round
    /// @return isRoundActive is the round active?
    /// @return isWithdrawalsEnabled are withdrawals enabled for the round?
    function getRoundInfo(uint256 _roundId)
        public
        view
        _checkRoundExists(_roundId)
        returns (uint256 roundId, string memory roundName, bool isRoundActive, bool isWithdrawalsEnabled)
    {
        roundId = rounds[_roundId].roundId;
        roundName = rounds[_roundId].roundName;
        isRoundActive = rounds[_roundId].isRoundActive;
        isWithdrawalsEnabled = rounds[_roundId].isWithdrawalsEnabled;
    }

    /// get if withdrawals are enabled for a round
    /// @param _roundId the id of the round to check
    /// @return isWithdrawalsEnabled are withdrawals enabled for the round?
    function getRoundWithdrawalsEnabled(uint256 _roundId)
        public
        view
        _checkRoundExists(_roundId)
        returns (bool isWithdrawalsEnabled)
    {
        isWithdrawalsEnabled = rounds[_roundId].isWithdrawalsEnabled;
    }
}
