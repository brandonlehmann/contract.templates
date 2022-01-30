// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/proxy/Clones.sol";
import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "../../@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../interfaces/IPaymentSplitter.sol";

contract ERC721SplitRoyaltyTemplate is
    ERC721Enumerable,
    ERC721Royalty,
    ERC721Pausable,
    AccessControlEnumerable
{
    using SafeERC20 for IERC20;
    using Strings for uint256;
    using Address for address;
    using Clones for address;

    event RoyaltyDeployed(
        address indexed _contract,
        uint256 indexed _tokenId,
        address indexed recipient
    );

    // Holds information about the royalty contracts for tracking purposes
    IPaymentSplitter public royaltyReceiver;

    // fee settings
    uint256 public MINTING_FEE;
    uint256 public MAX_TOKENS_PER_MINT = 1;

    // supply settings
    uint256 public immutable MAX_SUPPLY;

    // URI settings
    string private BASE_URI;
    string private URI_EXTENSION = ".json";
    bool private _revealed;

    // royalty settings
    uint96 public royaltyBasisNumerator;

    // The denominator with which to interpret the fee set for the royalty basis as a
    // fraction of the sale price. Set as 10000 so fees are expressed in basis points.
    uint96 public constant feeDenominator = 10000;

    // Pauser role ID
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _minting_fee,
        uint256 _max_supply,
        uint96 _royalty_basis_numerator,
        address _payment_splitter
    ) ERC721(_name, _symbol) {
        require(
            _payment_splitter != address(0),
            "payment splitter cannot be the null address"
        );
        royaltyReceiver = IPaymentSplitter(_payment_splitter.clone());
        royaltyReceiver.initialize();

        royaltyReceiver.addPayee(_msgSender(), 1);
        royaltyReceiver.addPayee(address(this), 9);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());

        MINTING_FEE = _minting_fee;
        MAX_SUPPLY = _max_supply;

        royaltyBasisNumerator = _royalty_basis_numerator;

        _pause();
    }

    /****** MINT METHODS ******/

    /**
     * @dev standard mint function that regular users call while
     * paying the appropriate mint fee to mint a ERC721
     */
    function mint() public payable virtual whenNotPaused returns (uint256) {
        require(msg.value == MINTING_FEE, "ERC721: wrong amount sent");

        return _mintERC721(_msgSender());
    }

    /**
     * @dev standard mint function that regular users call while
     * paying the appropriate mint fee to mint a number of ERC721s
     */
    function mint(uint256 count)
        public
        payable
        virtual
        whenNotPaused
        returns (uint256[] memory)
    {
        require(
            count <= MAX_TOKENS_PER_MINT,
            "ERC721: must mint less than the maximum count per mint"
        );
        require(msg.value == MINTING_FEE * count, "ERC721: wrong amount sent");

        uint256[] memory tokenIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _mintERC721(_msgSender());
        }

        return tokenIds;
    }

    /**
     * @dev mint process for admins only that allows overriding the
     * requirement for paying for the mint, allows minting while paused,
     * and mints the ERC721 directly to the wallet address specified
     */
    function mintAdmin(address _to)
        public
        virtual
        onlyRole(DEFAULT_ADMIN_ROLE)
        overridePause
        returns (uint256)
    {
        return _mintERC721(_to);
    }

    /**
     * @dev mint process for admins only that allows overriding the
     * requirement for paying for the mint, allows minting while paused,
     * overrides the maximum number of ERC721s per mint, and mints the
     * ERC721 directly to the wallet address specified for the specified count
     */
    function mintAdmin(address _to, uint256 count)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        overridePause
        returns (uint256[] memory)
    {
        uint256[] memory tokenIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _mintERC721(_to);
        }

        return tokenIds;
    }

    /**
     * @dev internal mint method that sets up the actual ERC721
     */
    function _mintERC721(address _to) internal virtual returns (uint256) {
        uint256 supply = totalSupply();
        require(supply + 1 <= MAX_SUPPLY, "mint completed");

        uint256 tokenId = supply + 1;

        _safeMint(_to, tokenId);

        return tokenId;
    }

    /****** BASIC SETTING METHODS ******/

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /****** FEE SETTING METHODS ******/

    function setMintFee(uint256 _minting_fee)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        MINTING_FEE = _minting_fee;
    }

    function setMaxTokensPerMint(uint256 _max_tokens_per_mint)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        MAX_TOKENS_PER_MINT = _max_tokens_per_mint;
    }

    /****** ROYALTY SETTINGS ******/

    /**
     * @dev instructs the royalty payment splitter for to pay all pending royalties
     */
    function payRoyalties() public {
        royaltyReceiver.releaseAll();
    }

    /**
     * @inheritdoc IERC2981
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        public
        view
        override
        returns (address, uint256)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: royalty query for non-existent token"
        );

        uint256 royaltyAmount = (_salePrice * royaltyBasisNumerator) /
            feeDenominator;

        return (address(royaltyReceiver), royaltyAmount);
    }

    /****** URI SETTINGS ******/

    /**
     * @dev reveals the token URIs
     */
    function reveal() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revealed = true;
    }

    /**
     * @dev returns if the token URI has been revealed
     */
    function revealed() public view returns (bool) {
        return _revealed;
    }

    /**
     * @dev updates the base URI for the token metadata to the provided URI
     */
    function setBaseURI(string memory _base_uri)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        BASE_URI = _base_uri;
    }

    /**
     * @dev updates the URI extension for the token metadata to the provided extension
     */
    function setURIExtension(string memory _extension)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        URI_EXTENSION = _extension;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (!_revealed) {
            return "";
        }

        return
            string(
                abi.encodePacked(BASE_URI, tokenId.toString(), URI_EXTENSION)
            );
    }

    /****** WITHDRAW METHODS ******/

    /**
     * @dev sends the full balance held by this contract to the caller
     */
    function withdraw() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(this).balance != 0, "contract has no balance");

        payable(_msgSender()).transfer(address(this).balance);
    }

    /**
     * @dev sends the full balance of the given token held by this contract to the caller
     */
    function withdraw(IERC20 token) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            token.balanceOf(address(this)) != 0,
            "contract has no balance of token"
        );

        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    }

    receive() external payable {}

    /****** INTERNAL OVERRIDES ******/

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        royaltyReceiver.releaseAll();

        super._afterTokenTransfer(from, to, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721Royalty) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            AccessControlEnumerable,
            ERC721,
            ERC721Enumerable,
            ERC721Royalty
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
