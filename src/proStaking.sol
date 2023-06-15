// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';


contract ProStaking is Initializable, ERC1155Upgradeable, ERC1155BurnableUpgradeable, AccessControlUpgradeable, ERC1155SupplyUpgradeable {
    using SafeERC20 for IERC20;
    bytes32 public constant PRICE_CONTROLLER = keccak256("PRICE_CONTROLLER");

    event Deposit(address indexed account, uint256 indexed tokenId, uint256 amount);
    event Withdraw(address indexed account, uint256 indexed tokenId, uint256 amount);
    event Slash(address indexed account, uint256 indexed tokenId, uint256 amount);
    event TransferDeposit(address indexed from, address indexed to, uint256 indexed tokenId, uint256 amount);

    IERC20 public depositToken;
    uint256 public upgradePrice;
    address public slashRecipient;

    mapping(uint256 => mapping(address => uint256)) public depositInfo;
    mapping(address => uint256[]) public tokensOwned;
    mapping(uint256 => mapping(address => uint256)) private indexOfTokenOwned;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _depositToken, uint256 _upgradePrice, address _slashRecipient) initializer public {
        __ERC1155_init("");
        __ERC1155Burnable_init();
        __AccessControl_init();
        __ERC1155Supply_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PRICE_CONTROLLER, msg.sender);

        depositToken = IERC20(_depositToken);
        upgradePrice = _upgradePrice;
        slashRecipient = _slashRecipient;
    }

    function depositAndMint(uint256 tokenId) external {
        require(depositInfo[tokenId][msg.sender] == 0, "Sender already has deposit for this token");
        depositToken.safeTransferFrom(msg.sender, address(this), upgradePrice);
        _mint(msg.sender, tokenId, 1, "");
        depositInfo[tokenId][msg.sender] = upgradePrice;
        tokensOwned[msg.sender].push(tokenId);
        indexOfTokenOwned[tokenId][msg.sender] = tokensOwned[msg.sender].length - 1;
        emit Deposit(msg.sender, tokenId, upgradePrice);
    }

    function _removeTokenFromOwnerArray(uint256 tokenId, address owner) internal {
        // find out the index of the token we wish to remove
        uint256 index = indexOfTokenOwned[tokenId][owner];
        // get the index of the last token in the array
        uint256 lastTokenIndex = tokensOwned[owner].length - 1;
        // get the last tokenID by index in the array of tokens owned by the owner
        uint256 lastToken = tokensOwned[owner][lastTokenIndex];
        // move the last token to the index of the token we wish to remove
        tokensOwned[owner][index] = lastToken;
        // remove the last token from the array
        tokensOwned[owner].pop();
        indexOfTokenOwned[tokenId][owner] = 0;
        indexOfTokenOwned[lastToken][owner] = index;
    }

    function _transferDepositFrom (address from, address to, uint256 tokenId) internal {
        uint256 depositAmount = depositInfo[tokenId][from];
        require(depositInfo[tokenId][to] == 0, "Recipient already has deposit for this token");
        require(depositAmount > 0, "No existing deposit for this token");
        depositInfo[tokenId][from] = 0;
        depositInfo[tokenId][to] = depositAmount;
        tokensOwned[to].push(tokenId);
        indexOfTokenOwned[tokenId][to] = tokensOwned[to].length - 1;
        _removeTokenFromOwnerArray(tokenId, from);
        emit TransferDeposit(from, to, tokenId, depositAmount);
    }

    function transferDeposit (address to, uint256 tokenId) external {
        _transferDepositFrom(msg.sender, to, tokenId);
    }

    function _withdrawAndBurn(uint256 tokenId, address account) internal {
        uint256 depositAmount = depositInfo[tokenId][account];
        require(depositAmount > 0, "No deposit");
        depositInfo[tokenId][account] = 0;
        _burn(account, tokenId, 1);
        depositToken.safeTransfer(account, depositAmount);
        _removeTokenFromOwnerArray(tokenId, account);
    }

    function withdrawAndBurn(uint256 tokenId) external {
       _withdrawAndBurn(tokenId, msg.sender);
       emit Withdraw(msg.sender, tokenId, depositInfo[tokenId][msg.sender]);
    }

    function setSlashRecipient(address _slashRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        slashRecipient = _slashRecipient;
    }

    function setPrice(uint256 _upgradePrice) external onlyRole(PRICE_CONTROLLER) {
        upgradePrice = _upgradePrice;
    }

    function slash(uint256 tokenId, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _withdrawAndBurn(tokenId, account);
        emit Slash(account, tokenId, depositInfo[tokenId][account]);
    }

    function getDepositPrice(uint256 tokenId, address account) external view returns (uint256) {
        return depositInfo[tokenId][account];
    }

    function getTokensByOwner(address owner) external view returns (uint256[] memory) {
        return tokensOwned[owner];
    }


    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
    {
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

    function name () public pure returns (string memory) {
        return "Giveth Pro Staking";
    }

    function symbol () public pure returns (string memory) {
        return "GIVPRO";
    }
}