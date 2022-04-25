// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../Cloneable/Cloneable.sol";
import "../interfaces/IPaymentSplitter.sol";
import "../interfaces/IContract.Registry.sol";

enum TokenType {
    NATIVE,
    ERC20,
    ERC721
}

interface IERC721Burnable is IERC721Enumerable {
    function burn(uint256 tokenId) external;
}

interface IFactoryNFT is ICloneable {
    function initialize(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        address paymentToken,
        TokenType tokenType
    ) external;

    function setMintPrice(uint256 fee) external;

    function setRoyaltyReceiver(address receiver, uint96 basisPoints) external;

    function transferOwnership(address newOwner) external;
}

contract ERC721Tiered is ERC721Enumerable, ERC721Royalty, ERC721Pausable, ERC721Burnable, Ownable, Cloneable {
    using Address for address;
    using SafeERC20 for IERC20;
    using Strings for uint256;

    uint256 public constant VERSION = 2022042401;

    event ChangeBurnedResupply(bool indexed _old, bool indexed _new);
    event ChangeMintPrice(uint256 indexed _old, uint256 indexed _new);
    event ChangeWhitelistDiscountBasis(uint96 indexed _old, uint256 indexed _new);
    event ChangeWhitelist(address indexed _account, bool _old, bool _new);
    event ChangePermittedContract(address indexed _contract, bool _old, bool _new);
    event ChangeMaxSupply(uint256 indexed _old, uint256 indexed _new);
    event ChangeRoyalty(address indexed receiver, uint96 indexed basisPoints);
    event ChangeProceedsRecipient(address indexed receiver);
    event CreatedTier(
        address indexed _contract,
        string indexed name,
        string indexed symbol,
        uint256 maxSupply,
        uint256 mintPrice
    );
    event TokenInitialized(
        string indexed name,
        string indexed symbol,
        uint256 maxSupply,
        address paymentToken,
        TokenType tokenType
    );
    event NullInitialized();

    // fee settings
    uint256 private _MINT_PRICE;
    uint96 public WHITELIST_DISCOUNT_BASIS; // expressed in basis points, 2000 = 20%

    // URI settings
    string public URI_PREFIX;
    string public URI_SUFFIX;
    bool public URI_UNIQUE = true;

    mapping(address => bool) public whitelist;
    mapping(address => bool) public permittedContractRecipient;
    uint256 public MAX_SUPPLY;
    uint256 public totalMinted;
    bool public BURNED_RESUPPLY = false;

    address public PAYMENT_TOKEN;
    TokenType public TOKEN_TYPE;
    IFactoryNFT public LAST_TIER;

    IPaymentSplitter public immutable BASE_PAYMENT_SPLITTER;
    IPaymentSplitter public ROYALTY_RECEIVER;
    IPaymentSplitter public PROCEEDS_RECIPIENT;
    uint96 public ROYALTY_BASIS;
    modifier whenProceedsRecipientSet() {
        if (TOKEN_TYPE != TokenType.ERC721) {
            require(address(PROCEEDS_RECIPIENT) != address(0), "Proceeds recipient is unset");
        }
        _;
    }

    constructor() ERC721("", "") {
        BASE_PAYMENT_SPLITTER = IPaymentSplitter(FTMContractRegistry.get("PaymentSplitter"));
        _transferOwnership(address(0));
    }

    function initialize() public initializer {
        emit NullInitialized();
    }

    function initialize(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        address paymentToken,
        TokenType tokenType
    ) public initializer {
        require(maxSupply > 0, "Max supply must be greater than 0");
        if (tokenType != TokenType.NATIVE) {
            require(paymentToken != address(0), "paymentToken must not be null address");
        }

        _transferOwnership(_msgSender()); // transfer ownership to caller

        _name = name;
        _symbol = symbol;
        MAX_SUPPLY = maxSupply;
        PAYMENT_TOKEN = paymentToken;
        TOKEN_TYPE = tokenType;

        _pause(); // always start paused to bot evade

        emit TokenInitialized(name, symbol, maxSupply, paymentToken, tokenType);
    }

    /****** PUBLIC METHODS ******/

    function mint(uint256 count) public payable whenNotPaused whenProceedsRecipientSet returns (uint256[] memory) {
        require(count != 0, "ERC721: Must mint at least one");
        uint256 mintCost = MINT_PRICE() * count;

        if (TOKEN_TYPE == TokenType.ERC20) {
            uint256 allowance = IERC20(PAYMENT_TOKEN).allowance(_msgSender(), address(this));
            require(mintCost <= IERC20(PAYMENT_TOKEN).balanceOf(_msgSender()), "ERC20: Mint price exceeds balance");
            require(mintCost <= allowance, "ERC20: Mint price exceeds allowance");

            IERC20(PAYMENT_TOKEN).safeTransferFrom(_msgSender(), address(PROCEEDS_RECIPIENT), mintCost);
            PROCEEDS_RECIPIENT.releaseAll(PAYMENT_TOKEN);
        } else if (TOKEN_TYPE == TokenType.ERC721) {
            require(
                IERC721Burnable(PAYMENT_TOKEN).isApprovedForAll(_msgSender(), address(this)),
                "ERC721: Contract not approved for spending"
            );
            require(
                mintCost <= IERC721Burnable(PAYMENT_TOKEN).balanceOf(_msgSender()),
                "ERC721: Mint price exceeds balance"
            );

            // loop through and burn the required tokens
            for (uint256 i = 0; i < mintCost; i++) {
                uint256 tokenId = IERC721Burnable(PAYMENT_TOKEN).tokenOfOwnerByIndex(_msgSender(), 0); // burn from the top of the pile
                try IERC721Burnable(PAYMENT_TOKEN).burn(tokenId) {} catch {
                    // try to burn, otherwise send to NullAddress 0x01 as 0x00 is usually restricted
                    IERC721Burnable(PAYMENT_TOKEN).safeTransferFrom(_msgSender(), address(1), tokenId);
                }
            }
        } else {
            // NATIVE
            require(
                mintCost == msg.value,
                string(abi.encodePacked("Caller supplied wrong value, required: ", mintCost.toString()))
            );
            (bool sent, ) = address(PROCEEDS_RECIPIENT).call{ value: msg.value }("");
            require(sent, "Could not distribute funds");
            PROCEEDS_RECIPIENT.releaseAll();
        }

        uint256[] memory tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _mintNFT(_msgSender());
        }
        return tokenIds;
    }

    function MINT_PRICE() public view returns (uint256) {
        if (TOKEN_TYPE != TokenType.ERC721) {
            if (whitelist[_msgSender()]) {
                return _MINT_PRICE - ((_MINT_PRICE * WHITELIST_DISCOUNT_BASIS) / 10_000);
            } else {
                return _MINT_PRICE;
            }
        }

        return _MINT_PRICE;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (URI_UNIQUE) {
            return string(abi.encodePacked(URI_PREFIX, tokenId.toString(), URI_SUFFIX));
        }

        return string(abi.encodePacked(URI_PREFIX, URI_SUFFIX));
    }

    /****** OWNER ONLY METHODS ******/

    function createTier(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        uint256 mintPrice
    ) public onlyOwner returns (address) {
        IFactoryNFT token = IFactoryNFT(clone());
        token.initialize(name, symbol, maxSupply, address(this), TokenType.ERC721);
        token.setMintPrice(mintPrice);
        token.transferOwnership(_msgSender());
        setPermittedContractRecipient(address(token), true);
        LAST_TIER = token;
        emit CreatedTier(address(token), name, symbol, maxSupply, mintPrice);
        return address(token);
    }

    function setBurnedResupply(bool state) public onlyOwner {
        bool old = BURNED_RESUPPLY;
        BURNED_RESUPPLY = state;
        emit ChangeBurnedResupply(old, state);
    }

    function setMaxSupply(uint256 maxSupply) public onlyOwner {
        require(maxSupply >= totalSupply(), "Max supply must be greater than or equal to current supply");
        uint256 old = MAX_SUPPLY;
        MAX_SUPPLY = maxSupply;
        emit ChangeMaxSupply(old, maxSupply);
    }

    function setMintPrice(uint256 fee) public onlyOwner {
        uint256 old = _MINT_PRICE;
        _MINT_PRICE = fee;
        emit ChangeMintPrice(old, fee);
    }

    function setPermittedContractRecipient(address recipient, bool state) public onlyOwner {
        bool old = permittedContractRecipient[recipient];
        permittedContractRecipient[recipient] = state;
        emit ChangePermittedContract(recipient, old, state);
    }

    function setProceedsRecipient(address[] memory recipients, uint256[] memory shares) public onlyOwner {
        PROCEEDS_RECIPIENT = IPaymentSplitter(BASE_PAYMENT_SPLITTER.clone());
        PROCEEDS_RECIPIENT.initialize(recipients, shares);
        emit ChangeProceedsRecipient(address(PROCEEDS_RECIPIENT));
    }

    function setRoyalty(
        address[] memory recipients,
        uint256[] memory shares,
        uint96 basisPoints
    ) public onlyOwner {
        ROYALTY_RECEIVER = IPaymentSplitter(BASE_PAYMENT_SPLITTER.clone());
        ROYALTY_RECEIVER.initialize(recipients, shares);
        _setDefaultRoyalty(address(ROYALTY_RECEIVER), basisPoints);
        ROYALTY_BASIS = basisPoints;
        emit ChangeRoyalty(address(ROYALTY_RECEIVER), basisPoints);
    }

    function setURISuffix(string memory suffix) public onlyOwner {
        URI_SUFFIX = suffix;
    }

    function setURIPrefix(string memory prefix) public onlyOwner {
        URI_PREFIX = prefix;
    }

    function setWhitelist(address account, bool state) public onlyOwner {
        bool old = whitelist[account];
        whitelist[account] = state;
        emit ChangeWhitelist(account, old, state);
    }

    function setWhitelistDiscountBasis(uint96 basisPoints) public onlyOwner {
        require(basisPoints <= 10_000, "Basis points must not exceed 10,000");
        uint96 old = WHITELIST_DISCOUNT_BASIS;
        WHITELIST_DISCOUNT_BASIS = basisPoints;
        emit ChangeWhitelistDiscountBasis(old, basisPoints);
    }

    function setURIUnique(bool state) public onlyOwner {
        URI_UNIQUE = state;
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /****** INTERNAL METHODS ******/

    function _mintNFT(address to) internal returns (uint256) {
        totalMinted++;
        if (!BURNED_RESUPPLY) {
            require(totalMinted <= MAX_SUPPLY, "ERC721: Mint exceeds MAX_SUPPLY");
        } else {
            require(totalSupply() + 1 <= MAX_SUPPLY, "ERC721: Mint exceeds MAX_SUPPLY");
        }
        _safeMint(to, totalMinted);
        return totalMinted;
    }

    function _beforeApprove(address to, uint256 tokenId) internal override {
        if (to.isContract()) {
            require(permittedContractRecipient[to], "ERC721: Contract not whitelisted for approvals");
        }

        super._beforeApprove(to, tokenId);
    }

    function _beforeApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal override {
        if (approved && operator.isContract()) {
            require(permittedContractRecipient[operator], "ERC721: Contract not whitelisted for approvals");
        }

        super._beforeApprovalForAll(owner, operator, approved);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable, ERC721Pausable) {
        if (to.isContract()) {
            require(permittedContractRecipient[to], "ERC721: Contract not whitelisted for transfers");
        }

        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        if (address(ROYALTY_RECEIVER) != address(0)) {
            ROYALTY_RECEIVER.releaseAll();
        }

        super._afterTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721Royalty) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable, ERC721Royalty)
        returns (bool)
    {
        return ERC721Enumerable.supportsInterface(interfaceId) || ERC721Royalty.supportsInterface(interfaceId);
    }
}
