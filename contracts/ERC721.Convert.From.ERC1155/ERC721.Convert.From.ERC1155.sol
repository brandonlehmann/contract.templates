// SPDX-License-Identifier: MIT
// Brandon Lehmann <brandonlehmann@gmail.com>

pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "../../@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../Cloneable/Cloneable.sol";
import "../PaymentSplitter/PaymentSplitter.sol";

interface IERC1155Burnable is IERC1155 {
    function burn(
        address account,
        uint256 id,
        uint256 value
    ) external;
}

contract ERC721Template is ERC721Enumerable, ERC721Royalty, Ownable, Cloneable {
    using Strings for uint256;

    event TokenInitialized(
        address indexed convertible,
        string indexed name,
        string indexed symbol,
        address royaltyReceiver,
        uint96 roayltyBasisPoints
    );

    // URI settings
    mapping(uint256 => string) private TOKEN_URI;
    string private URI_PREFIX;
    string private URI_SUFFIX = ".json";

    // royalty settings
    IPaymentSplitter internal immutable BASE_PAYMENT_SPLITTER;
    address internal immutable deployer;

    IERC1155Burnable public CONVERTIBLE;
    IPaymentSplitter ROYALTIES_RECEIVER;
    uint256 private _nextTokenId;

    constructor() ERC721("", "") {
        BASE_PAYMENT_SPLITTER = new PaymentSplitter();
        BASE_PAYMENT_SPLITTER.initialize();
        BASE_PAYMENT_SPLITTER.transferOwnership(address(0));
        deployer = _msgSender();
        _transferOwnership(address(0));
    }

    function initialize() public initializer {}

    function intitialize(
        address convertible,
        string memory name_,
        string memory symbol_,
        address royaltyReceiver,
        uint96 royaltyBasisPoints,
        uint256 nextTokenId
    ) public initializer {
        _name = name_;
        _symbol = symbol_;
        CONVERTIBLE = IERC1155Burnable(convertible);
        _nextTokenId = nextTokenId;

        ROYALTIES_RECEIVER = IPaymentSplitter(BASE_PAYMENT_SPLITTER.clone());
        ROYALTIES_RECEIVER.initialize();
        ROYALTIES_RECEIVER.addPayee(deployer, 20); // developer gets 20%
        ROYALTIES_RECEIVER.addPayee(royaltyReceiver, 80); // receiver gets 80%
        ROYALTIES_RECEIVER.transferOwnership(address(0));

        _setDefaultRoyalty(address(ROYALTIES_RECEIVER), royaltyBasisPoints);

        _transferOwnership(_msgSender());

        emit TokenInitialized(convertible, name_, symbol_, royaltyReceiver, royaltyBasisPoints);
    }

    /**
     * @dev returns if this contract is approved for managing the ERC1155
     */
    function isApproved() public view returns (bool) {
        return isApproved(_msgSender());
    }

    /**
     * @dev returns if this contract is approved for managing the ERC1155
     */
    function isApproved(address account) public view returns (bool) {
        return CONVERTIBLE.isApprovedForAll(account, address(this));
    }

    /**
     * @dev mints a new NFT to the caller
     */
    function mint() public onlyOwner {
        require(_nextTokenId != 0, "minting not enabled");
        _safeMint(_msgSender(), _nextTokenId++);
    }

    /**
     * @dev migrates the ERC1155 token(s) to ERC721 token(s)
     */
    function migrate(uint256[] memory tokenIds) public {
        require(isApproved(_msgSender()), "Not approved for ERC1155 management");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                !_exists(tokenIds[i]),
                string(abi.encodePacked("Token ID ", tokenIds[i].toString(), " already exists"))
            );
            uint256 balance = CONVERTIBLE.balanceOf(_msgSender(), tokenIds[i]);
            require(balance != 0, string(abi.encodePacked("Missing balance of token ID ", tokenIds[i].toString())));

            try CONVERTIBLE.burn(_msgSender(), tokenIds[i], balance) {} catch {
                CONVERTIBLE.safeTransferFrom(_msgSender(), address(1), tokenIds[i], balance, "");
            }

            _safeMint(_msgSender(), tokenIds[i]);
        }
    }

    /**
     * @dev Updates the royalty receiver
     */
    function updateRoyaltyReceiver(address royaltyReceiver, uint96 royaltyBasisPoints) public onlyOwner {
        ROYALTIES_RECEIVER = IPaymentSplitter(BASE_PAYMENT_SPLITTER.clone());
        ROYALTIES_RECEIVER.initialize();
        ROYALTIES_RECEIVER.addPayee(deployer, 20); // developer gets 20%
        ROYALTIES_RECEIVER.addPayee(royaltyReceiver, 80); // receiver gets 80%
        ROYALTIES_RECEIVER.transferOwnership(address(0));

        _setDefaultRoyalty(address(ROYALTIES_RECEIVER), royaltyBasisPoints);
    }

    /**
     * @dev Updates the URI Prefix for the token URIs
     */
    function setURIPrefix(string memory prefix) public onlyOwner {
        URI_PREFIX = prefix;
    }

    /**
     * @dev Updates the URI Suffix for the token URIs
     */
    function setURISuffix(string memory suffix) public onlyOwner {
        URI_SUFFIX = suffix;
    }

    /**
     * @dev sets a token specific URI
     */
    function setTokenURI(uint256 tokenId, string memory uri) public onlyOwner {
        require(_exists(tokenId), "ERC721Metadata: Cannot set URI for nonexistent token");
        TOKEN_URI[tokenId] = uri;
    }

    /**
     * @dev Returns the URI for the specified token if it exists
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (bytes(TOKEN_URI[tokenId]).length != 0) {
            return TOKEN_URI[tokenId];
        }

        return string(abi.encodePacked(URI_PREFIX, tokenId.toString(), URI_SUFFIX));
    }

    //****** INTERNAL METHODS ******/

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        ROYALTIES_RECEIVER.releaseAll();

        super._afterTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721Royalty) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
