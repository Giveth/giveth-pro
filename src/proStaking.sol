// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

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

    error WithdrawalsDisabled();
    error NoDepositExists();
    error RecipientAlreadyHasDeposit();
    error CannotTransferToSelf();
    error CannotBeZero();

    IERC20 public depositToken;
    uint256 public upgradePrice;
    address public slashRecipient;
    bool public isWithdrawalsEnabled;

    mapping(uint256 => mapping(address => uint256)) public depositInfo;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _depositToken, uint256 _upgradePrice, address _slashRecipient) public initializer {
        __ERC1155_init('');
        __ERC1155Burnable_init();
        __AccessControl_init();
        __ERC1155Supply_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PRICE_CONTROLLER, msg.sender);
        isWithdrawalsEnabled = true;
        depositToken = IERC20(_depositToken);
        upgradePrice = _upgradePrice;
        slashRecipient = _slashRecipient;
    }

    function depositAndMint(uint256 tokenId) external {
        if (depositInfo[tokenId][msg.sender] > 0) {
            revert RecipientAlreadyHasDeposit();
        }
        depositToken.safeTransferFrom(msg.sender, address(this), upgradePrice);
        _mint(msg.sender, tokenId, 1, '');
        depositInfo[tokenId][msg.sender] = upgradePrice;
        emit Deposit(msg.sender, tokenId, upgradePrice);
        emit AddStake(msg.sender, tokenId);
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
        emit TransferDeposit(from, to, tokenId, depositAmount);
        emit RemoveStake(from, tokenId);
        emit AddStake(to, tokenId);
    }

    function transferDeposit(address to, uint256 tokenId) external {
        _transferDepositFrom(msg.sender, to, tokenId);
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

    function withdrawAndBurn(uint256 tokenId) external {
        uint256 priceWithdrawn = depositInfo[tokenId][msg.sender];
        if (isWithdrawalsEnabled == false) {
            revert WithdrawalsDisabled();
        }
        _withdrawAndBurn(tokenId, msg.sender, msg.sender);
        emit Withdraw(msg.sender, tokenId, priceWithdrawn);
    }

    function slash(uint256 tokenId, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 amountSlashed = depositInfo[tokenId][account];
        _withdrawAndBurn(tokenId, account, slashRecipient);
        emit Slash(account, tokenId, amountSlashed);
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

    function setWithdrawalsEnabled(bool _isWithdrawalsEnabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isWithdrawalsEnabled = _isWithdrawalsEnabled;
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
