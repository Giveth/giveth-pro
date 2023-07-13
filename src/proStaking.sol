// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

interface IRoundManager {
    function getRoundWithdrawalsEnabled(uint256 roundId) external view returns (bool);

    function getActiveRounds() external view returns (uint256[] memory);

    function roundsCreated() external view returns (uint256);
}

contract ProStaking is
    Initializable,
    ERC1155Upgradeable,
    ERC1155BurnableUpgradeable,
    AccessControlUpgradeable,
    ERC1155SupplyUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant PRICE_CONTROLLER = keccak256('PRICE_CONTROLLER');

    event Deposit(address indexed account, uint256 indexed tokenId, uint256 amount);
    event Withdraw(address indexed account, uint256 indexed tokenId, uint256 amount);
    event Slash(address indexed account, uint256 indexed tokenId, uint256 amount);
    event AddStake(address indexed account, uint256 tokenId);
    event RemoveStake(address indexed account, uint256 tokenId);
    event TransferDeposit(address indexed from, address indexed to, uint256 indexed tokenId, uint256 amount);
    event AppliedForRound(address indexed account, uint256 indexed tokenId, uint256 roundId);
    event UnappliedForRound(address indexed account, uint256 indexed tokenId, uint256 roundId);

    error RoundLocked(uint256 roundId);
    error NoDepositExists();
    error RecipientAlreadyHasDeposit();
    error CannotTransferToSelf();
    error CannotBeZero();
    error AlreadyAppliedForRound(uint256 roundId);
    error RoundNotActive(uint256 roundId);

    IERC20 public depositToken;
    uint256 public upgradePrice;
    address public slashRecipient;
    // bool public isWithdrawalsEnabled;
    IRoundManager public roundManager;

    // mapping of tokenId => DepositorAddress => depositAmount | this informs us of the amount the depositor is eligible to withdraw for a given tokenId they hold
    mapping(uint256 => mapping(address => uint256)) public depositInfo;

    // mapping of roundId => can user make withdrawals?
    // mapping(uint256 => bool) public isRoundRoundLocked;

    // mapping of tokenId => DepositorAddress => roundId => hasApplied?
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public appliedForRound;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _depositToken, uint256 _upgradePrice, address _slashRecipient, address _roundManager)
        public
        initializer
    {
        __ERC1155_init('');
        __ERC1155Burnable_init();
        __AccessControl_init();
        __ERC1155Supply_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PRICE_CONTROLLER, msg.sender);
        //  isWithdrawalsEnabled = true;
        depositToken = IERC20(_depositToken);
        upgradePrice = _upgradePrice;
        slashRecipient = _slashRecipient;
        roundManager = IRoundManager(_roundManager);
    }

    function _depositAndMint(uint256 tokenId) internal {
        if (depositInfo[tokenId][msg.sender] > 0) {
            revert RecipientAlreadyHasDeposit();
        }
        depositToken.safeTransferFrom(msg.sender, address(this), upgradePrice);
        _mint(msg.sender, tokenId, 1, '');
        depositInfo[tokenId][msg.sender] = upgradePrice;
        emit Deposit(msg.sender, tokenId, upgradePrice);
        emit AddStake(msg.sender, tokenId);
    }

    function depositAndMint(uint256 tokenId) external {
        _depositAndMint(tokenId);
    }

    function _applyForRound(uint256 tokenId, uint256 roundId) internal {
        uint256[] memory activeRounds = roundManager.getActiveRounds();
        bool roundFound = false;
        for (uint256 i = 0; i < activeRounds.length; i++) {
            if (activeRounds[i] == roundId) {
                roundFound = true;
                break;
            }
        }
        if (!roundFound) {
            revert RoundNotActive(roundId);
        }

        if (this.balanceOf(msg.sender, tokenId) == 0) {
            revert NoDepositExists();
        }
        if (appliedForRound[tokenId][msg.sender][roundId] == true) {
            revert AlreadyAppliedForRound(roundId);
        }
        appliedForRound[tokenId][msg.sender][roundId] = true;
        emit AppliedForRound(msg.sender, tokenId, roundId);
    }

    function applyForRound(uint256 tokenId, uint256 roundId) external {
        _applyForRound(tokenId, roundId);
    }

    function depositAndApplyForRound(uint256 tokenId, uint256 roundId) external {
        _depositAndMint(tokenId);
        _applyForRound(tokenId, roundId);
    }

    function _transferDepositFrom(address from, address to, uint256 tokenId) internal {
        uint256 depositAmount = depositInfo[tokenId][from];
        if (from == to) {
            revert CannotTransferToSelf();
        }
        if (depositInfo[tokenId][to] > 0) {
            revert RecipientAlreadyHasDeposit();
        }
        if (depositAmount == 0) {
            revert NoDepositExists();
        }
        safeTransferFrom(from, to, tokenId, 1, '');
        depositInfo[tokenId][from] = 0;
        depositInfo[tokenId][to] = depositAmount;
        uint256[] memory activeRounds = roundManager.getActiveRounds();
        for (uint256 i = 0; i < activeRounds.length; i++) {
            if (appliedForRound[tokenId][from][activeRounds[i]] == true) {
                appliedForRound[tokenId][from][activeRounds[i]] = false;
                appliedForRound[tokenId][to][activeRounds[i]] = true;
                emit UnappliedForRound(from, tokenId, activeRounds[i]);
                emit AppliedForRound(to, tokenId, activeRounds[i]);
            }
        }

        emit TransferDeposit(from, to, tokenId, depositAmount);
        emit RemoveStake(from, tokenId);
        emit AddStake(to, tokenId);
    }

    function transferDeposit(address to, uint256 tokenId) external {
        _transferDepositFrom(msg.sender, to, tokenId);
    }

    modifier _checkRoundLocked(address account, uint256 tokenId) {
        uint256[] memory activeRounds = roundManager.getActiveRounds();
        for (uint256 i = 0; i < activeRounds.length; i++) {
            bool isWithdrawalsEnabled = roundManager.getRoundWithdrawalsEnabled(activeRounds[i]);
            if (appliedForRound[tokenId][account][activeRounds[i]] == true && isWithdrawalsEnabled == false) {
                revert RoundLocked(activeRounds[i]);
            }
        }
        _;
    }

    function _withdrawAndBurn(uint256 tokenId, address account, address depositRecipient) internal {
        uint256 depositAmount = depositInfo[tokenId][account];
        if (depositAmount == 0) {
            revert NoDepositExists();
        }
        depositInfo[tokenId][account] = 0;
        _burn(account, tokenId, 1);
        depositToken.safeTransfer(depositRecipient, depositAmount);
        emit RemoveStake(account, tokenId);
    }

    function withdrawAndBurn(uint256 tokenId) external _checkRoundLocked(msg.sender, tokenId) {
        uint256 priceWithdrawn = depositInfo[tokenId][msg.sender];
        _withdrawAndBurn(tokenId, msg.sender, msg.sender);
        _unapplyForAllRounds(msg.sender, tokenId);
        emit Withdraw(msg.sender, tokenId, priceWithdrawn);
    }

    function slash(uint256 tokenId, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 amountSlashed = depositInfo[tokenId][account];
        _withdrawAndBurn(tokenId, account, slashRecipient);
        _unapplyForAllRounds(account, tokenId);
        emit Slash(account, tokenId, amountSlashed);
    }

    function unapplyForRound(uint256 tokenId, uint256 roundId) external _checkRoundLocked(msg.sender, tokenId) {
        if (appliedForRound[tokenId][msg.sender][roundId] == false) {
            revert CannotBeZero();
        }
        _unapplyForRound(msg.sender, tokenId, roundId);
    }

    function _unapplyForRound(address account, uint256 tokenId, uint256 roundId) internal {
        appliedForRound[tokenId][account][roundId] = false;
        emit UnappliedForRound(account, tokenId, roundId);
    }

    function _unapplyForAllRounds(address account, uint256 tokenId) internal {
        uint256[] memory activeRounds = roundManager.getActiveRounds();
        for (uint256 i = 0; i < activeRounds.length; i++) {
            if (appliedForRound[tokenId][account][activeRounds[i]] == true) {
                _unapplyForRound(account, tokenId, activeRounds[i]);
            }
        }
    }

    function setSlashRecipient(address _slashRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        slashRecipient = _slashRecipient;
    }

    function setPrice(uint256 _upgradePrice) external onlyRole(PRICE_CONTROLLER) {
        if (_upgradePrice <= 0) {
            revert CannotBeZero();
        }
        upgradePrice = _upgradePrice;
    }

    function setRoundManager(address _roundManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        roundManager = IRoundManager(_roundManager);
    }

    function getDepositPrice(uint256 tokenId, address account) external view returns (uint256) {
        return depositInfo[tokenId][account];
    }

    function name() public pure returns (string memory) {
        return 'Giveth Pro Staking';
    }

    function symbol() public pure returns (string memory) {
        return 'GIVPRO';
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
