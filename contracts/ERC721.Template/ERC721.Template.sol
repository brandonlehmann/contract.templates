// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "../../@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../../@openzeppelin/contracts/proxy/Clones.sol";
import "../interfaces/IRoyaltyManager.sol";
import "../interfaces/IPaymentSplitter.sol";
import "../interfaces/IBlockTimeTracker.sol";
import "../interfaces/IWhitelistManager.sol";

abstract contract ERC721Template is
    ERC721Enumerable,
    ERC721Royalty,
    ERC721Pausable,
    AccessControlEnumerable,
    Initializable
{
    using SafeERC20 for IERC20;
    using Strings for uint256;
    using Address for address;
    using Clones for address;

    uint256 public constant VERSION = 2022021401;

    // fee settings
    uint256 public MINTING_FEE;
    uint256 public MAX_SUPPLY;
    uint256 public MAX_TOKENS_PER_MINT;

    // URI settings
    string private BASE_URI;
    string private URI_EXTENSION = ".json";

    // Royalty settings
    address public ROYALTY_MANAGER;
    uint96 public royaltyBasisPoints;
    address private immutable deployer;

    // Pauser role ID
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SERVICE_ROLE = keccak256("SERVICE_ROLE");

    // random seed for used in tokenURI generation
    uint256 private RANDOM_SEED;

    // copy of the whitelist manager
    address public WHITELIST_MANAGER;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(SERVICE_ROLE, _msgSender());
        deployer = _msgSender();

        _pause();
    }

    /**
     * @dev initializes the abstract class for further use
     */
    function initialize(
        uint256 _maxSupply,
        uint256 _mintingFee,
        uint256 _maxTokensPerMint,
        IBlockTimeTracker _blockTimeTracker,
        address _royaltyManager,
        address _whitelistManager,
        uint96 _royaltyBasisPoints
    ) public onlyRole(DEFAULT_ADMIN_ROLE) initializer {
        require(
            _royaltyManager != address(0),
            "RoyaltyManager cannot be null address"
        );
        require(
            IRoyaltyManager(_royaltyManager).VERSION() == VERSION,
            "RoyaltyManager is wrong version"
        );
        require(
            address(_blockTimeTracker) != address(0),
            "BlockTimeTracker cannot be null address"
        );
        require(
            _blockTimeTracker.VERSION() == VERSION,
            "BlockTimeTracker is wrong version"
        );
        require(
            _whitelistManager != address(0),
            "WhitelistManager cannot be null address"
        );
        require(
            IWhitelistManager(_whitelistManager).VERSION() == VERSION,
            "WhitelistManager is wrong version"
        );

        MAX_SUPPLY = _maxSupply;
        MINTING_FEE = _mintingFee;
        MAX_TOKENS_PER_MINT = _maxTokensPerMint;
        royaltyBasisPoints = _royaltyBasisPoints;

        // clone the royalty manager and load it
        ROYALTY_MANAGER = _royaltyManager.clone();
        IRoyaltyManager(ROYALTY_MANAGER).initialize(
            _msgSender(),
            1,
            address(this),
            1
        );

        // clone the whitelist manager and load it
        WHITELIST_MANAGER = _whitelistManager.clone();
        IWhitelistManager(WHITELIST_MANAGER).pause();

        RANDOM_SEED = uint256(
            keccak256(
                abi.encodePacked(
                    _msgSender(),
                    block.timestamp,
                    block.number,
                    address(this),
                    _blockTimeTracker.average(6)
                )
            )
        );

        _setDefaultRoyalty(ROYALTY_MANAGER, royaltyBasisPoints);
    }

    /****** WHITELIST METHODS ******/

    function addToWhitelist(address account, uint256 count)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenInitialized
    {
        IWhitelistManager(WHITELIST_MANAGER).add(account, count);
    }

    function removeFromWhitelist(address account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenInitialized
    {
        IWhitelistManager(WHITELIST_MANAGER).remove(account);
    }

    function pauseWhitelist()
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenInitialized
    {
        IWhitelistManager(WHITELIST_MANAGER).pause();
    }

    function unpauseWhitelist()
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenInitialized
    {
        IWhitelistManager(WHITELIST_MANAGER).unpause();
    }

    function whitelistPaused() public view whenInitialized returns (bool) {
        return IWhitelistManager(WHITELIST_MANAGER).paused();
    }

    /****** MINT METHODS ******/

    /**
     * @dev overrides our pause such that a whitelisted account, if the script is paused
     * can still call the mint method & transfer NFTs
     */
    function paused() public view override returns (bool) {
        (bool isWhitelisted, uint256 mintsRemaining) = IWhitelistManager(
            WHITELIST_MANAGER
        ).check(_msgSender());

        if (
            !IWhitelistManager(WHITELIST_MANAGER).paused() &&
            isWhitelisted &&
            mintsRemaining > 0
        ) {
            return false;
        }

        return super.paused();
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
        whenInitialized
        returns (uint256[] memory)
    {
        require(count != 0, "ERC20: must mint at least one");
        require(
            count <= MAX_TOKENS_PER_MINT,
            "ERC20: max tokens per mint exceeded"
        );
        require(
            msg.value == MINTING_FEE * count,
            "ERC20: caller did not supply correct amount"
        );

        // if the whitelist is active and the contract is paused
        // we have to be able to reduce the number of mints available
        // to the account in the whitelist by the requested account
        if (!IWhitelistManager(WHITELIST_MANAGER).paused() && super.paused()) {
            IWhitelistManager(WHITELIST_MANAGER).decrement(_msgSender(), count);
        }

        uint256[] memory tokenIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _mintNFT(_msgSender());
        }

        return tokenIds;
    }

    /**
     * @dev mint process for admins only that allows overriding the
     * requirement for paying for the mint, allows minting while paused,
     * overrides the maximum number of ERC721s per mint, and mints the
     * ERC721 directly to the wallet address specified for the specified count
     */
    function adminMint(address _to, uint256 count)
        public
        virtual
        onlyRole(DEFAULT_ADMIN_ROLE)
        overridePause
        whenInitialized
        returns (uint256[] memory)
    {
        require(count != 0, "ERC20: must mint at least one");
        require(
            count <= MAX_TOKENS_PER_MINT,
            "ERC20: max tokens per mint exceeded"
        );

        uint256[] memory tokenIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _mintNFT(_to);
        }

        return tokenIds;
    }

    /**
     * @dev burns the specified token ID
     */
    function burn(uint256 tokenId) public whenInitialized {
        _burn(tokenId);
    }

    /**
     * @dev internal mint method that sets up the actual ERC721
     */
    function _mintNFT(address _to) internal virtual returns (uint256) {
        uint256 supply = totalSupply();
        require(supply + 1 <= MAX_SUPPLY, "ERC20: Mint Complete");

        uint256 tokenId = supply + 1;

        address royaltyReceiver = IRoyaltyManager(ROYALTY_MANAGER).add(
            tokenId,
            1,
            _to,
            1
        );

        _setTokenRoyalty(tokenId, royaltyReceiver, royaltyBasisPoints);

        _safeMint(_to, tokenId);

        return tokenId;
    }

    /****** BASIC SETTING METHODS ******/

    /**
     * @dev pauses the minting & transfers
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /*
     * @dev unpauses the minting & transfers
     */
    function unpause() public onlyRole(PAUSER_ROLE) whenInitialized {
        _unpause();
    }

    /****** FEE SETTING METHODS ******/

    /**
     * @dev updates the minting fee
     */
    function setMintFee(uint256 _minting_fee)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        MINTING_FEE = _minting_fee;
    }

    /****** URI SETTINGS ******/

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
     * @dev updates the URI extension for the token meta data to the provided one
     */
    function setURIExtension(string memory _uri_extension)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        URI_EXTENSION = _uri_extension;
    }

    /**
     * @dev Generates a masked token URI so that people cannot guess what the next
     * NFT result will be
     */
    function _generateTokenURI(uint256 tokenId)
        internal
        view
        virtual
        returns (string memory)
    {
        return
            uint256(
                keccak256(
                    abi.encodePacked(RANDOM_SEED.toString(), tokenId.toString())
                )
            ).toHexString(32);
    }

    /**
     * @dev returns the token masked URI for the given token Id
     */
    function tokenMaskedURI(uint256 tokenId)
        public
        view
        virtual
        onlyRole(SERVICE_ROLE)
        whenInitialized
        returns (string memory)
    {
        return _generateTokenURI(tokenId);
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

        return
            string(
                abi.encodePacked(
                    BASE_URI,
                    _generateTokenURI(tokenId),
                    URI_EXTENSION
                )
            );
    }

    /****** WITHDRAW METHOD ******/

    /**
     * @dev sends the full balance of the given token (or 0x0 for native)
     * held by this contract to the caller
     */
    function withdraw(IERC20 token) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(token) != address(0)) {
            require(
                token.balanceOf(address(this)) != 0,
                "contract has no balance of token"
            );
        } else {
            require(address(this).balance != 0, "contract has no balance");
        }

        address splitter = IRoyaltyManager(ROYALTY_MANAGER).cloneSplitter();
        IPaymentSplitter(splitter).addPayee(_msgSender(), 90);

        if (_msgSender() != deployer) {
            IPaymentSplitter(splitter).addPayee(deployer, 10);
        }

        if (address(token) != address(0)) {
            token.safeTransfer(splitter, token.balanceOf(address(this)));
            IPaymentSplitter(splitter).releaseAll(address(token));
        } else {
            payable(splitter).transfer(address(this).balance);
            IPaymentSplitter(splitter).releaseAll();
        }
    }

    receive() external payable {}

    /****** INTERNAL OVERRIDES ******/

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        IRoyaltyManager(ROYALTY_MANAGER).releaseAll(tokenId);

        super._afterTokenTransfer(from, to, tokenId);
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
