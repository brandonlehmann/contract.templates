// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "../../@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../../@openzeppelin/contracts/proxy/Clones.sol";
import "../interfaces/IUniswapV2TWAPOracle.sol";
import "../interfaces/IPaymentSplitter.sol";
import "../interfaces/IBlockTimeTracker.sol";
import "../interfaces/ITimmyNFT.sol";

contract ERC721Template is
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

    // fee settings
    uint256 public MINTING_FEE = 10 ether;
    uint256 public immutable MAX_TOKENS_PER_MINT = 10;
    uint96 public FTM_PREMIUM = 12500;
    address public immutable TRADING_PAIR =
        address(0xa8DE5367290Ed79658A9f9B9Ae1f633c355f1e1F);
    IERC20 public immutable PAYMENT_TOKEN =
        IERC20(0x6a31Aca4d2f7398F04d9B6ffae2D898d9A8e7938);
    IUniswapV2TWAPOracle public immutable ORACLE =
        IUniswapV2TWAPOracle(0x4B1B9F7ce4C40E9EdC1453F421Cf5CaeC384A085);

    // supply settings
    uint256 public immutable MAX_SUPPLY = 1000;

    // URI settings
    string private BASE_URI;
    string private URI_EXTENSION = ".json";

    // Royalty settings
    address public PAYMENT_SPLITTER =
        address(0xaab3D332F05Af59A3Ada9Df9b7D3CED6EBe6b919);
    IPaymentSplitter public baseRoyaltyReceiver;
    mapping(address => IPaymentSplitter) public knownRoyaltyReceivers;
    mapping(uint256 => address) public tokenRoyaltyReceiver;
    address private immutable deployer;

    // Pauser role ID
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SERVICE_ROLE = keccak256("SERVICE_ROLE");

    // random seed for used in tokenURI generation
    uint256 private immutable RANDOM_SEED;
    // BlockTimeTracker for randomization
    IBlockTimeTracker private constant tracker =
        IBlockTimeTracker(0x706e05D2b47cc6B1fb615EE76DD3789d2329E22e);

    constructor() ERC721("TurtleTurtle.club: The Timmy Collection", "TIMMY") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(SERVICE_ROLE, _msgSender());
        deployer = _msgSender();

        baseRoyaltyReceiver = IPaymentSplitter(PAYMENT_SPLITTER.clone());
        baseRoyaltyReceiver.initialize();
        baseRoyaltyReceiver.addPayee(_msgSender(), 4);
        baseRoyaltyReceiver.addPayee(address(this), 6);

        RANDOM_SEED = uint256(
            keccak256(
                abi.encodePacked(
                    _msgSender(),
                    block.timestamp,
                    block.number,
                    address(this),
                    tracker.average()
                )
            )
        );

        emit RoyaltyDeployed(address(baseRoyaltyReceiver), 0, address(this));

        _setDefaultRoyalty(
            address(baseRoyaltyReceiver),
            500 // in basis points, 5%
        );

        _pause();
    }

    /****** ROYALTY SETTINGS ******/

    function _constructRoyaltyReceiver(uint256 tokenId, address receiver)
        internal
    {
        if (address(knownRoyaltyReceivers[receiver]) == address(0)) {
            knownRoyaltyReceivers[receiver] = IPaymentSplitter(
                PAYMENT_SPLITTER.clone()
            );
            knownRoyaltyReceivers[receiver].initialize();
            knownRoyaltyReceivers[receiver].addPayee(
                address(baseRoyaltyReceiver),
                1
            );
            knownRoyaltyReceivers[receiver].addPayee(receiver, 1);

            emit RoyaltyDeployed(
                address(knownRoyaltyReceivers[receiver]),
                tokenId,
                receiver
            );
        }

        tokenRoyaltyReceiver[tokenId] = receiver;
    }

    /**
     * @dev Returns the pending royalties due to the original minter of the given token Id
     */
    function pendingRoyalties(uint256 tokenId) public view returns (uint256) {
        if (!_exists(tokenId)) {
            return 0;
        }

        return
            knownRoyaltyReceivers[tokenRoyaltyReceiver[tokenId]].pending(
                tokenRoyaltyReceiver[tokenId]
            );
    }

    /**
     * @dev Returns the pending royalties due to the original minter specified
     */
    function pendingRoyalties(address minter) public view returns (uint256) {
        if (address(knownRoyaltyReceivers[minter]) == address(0)) {
            return 0;
        }

        return knownRoyaltyReceivers[minter].pending(minter);
    }

    /**
     * @dev Pays out any pending royalties due to the specified original minter
     */
    function releaseRoyalties(address minter) public {
        require(
            address(knownRoyaltyReceivers[minter]) != address(0),
            "not an original minter"
        );
        knownRoyaltyReceivers[minter].releaseAll();
    }

    /****** MINT METHODS ******/

    function getFTMQuote() public view returns (uint256) {
        uint256 ftmRate = ORACLE.consultCurrent(
            TRADING_PAIR,
            address(PAYMENT_TOKEN),
            MINTING_FEE
        );

        return ftmRate + ((ftmRate * FTM_PREMIUM) / 10000);
    }

    function getFTMQuoteSlippage()
        internal
        view
        returns (uint256 _min, uint256 _max)
    {
        uint256 mintFee = getFTMQuote();
        _min = (mintFee * 9750) / 10000; // allows for -2.5%
        _max = (mintFee * 10250) / 10000; // allows for +2.5%
    }

    function updateOracle() internal {
        ORACLE.update(TRADING_PAIR);
    }

    /**
     * @dev standard mint function that regular users call while
     * paying the appropriate mint fee to mint the ERC721
     */
    function mint() public payable whenNotPaused returns (uint256) {
        (uint256 min, uint256 max) = getFTMQuoteSlippage();
        require(
            msg.value >= min && msg.value <= max,
            "ERC20: caller did not supply correct amount of FTM"
        );

        updateOracle();

        return _mintERC721(_msgSender());
    }

    /**
     * @dev standard mint function that regular users call while
     * paying the appropriate mint fee to mint a number of ERC721s
     */
    function mintCount(uint8 count)
        public
        payable
        whenNotPaused
        returns (uint256[] memory)
    {
        require(
            count <= MAX_TOKENS_PER_MINT,
            "ERC721: must mint less than the maximum count per mint"
        );

        (uint256 min, uint256 max) = getFTMQuoteSlippage();

        require(
            msg.value >= min * count && msg.value <= max * count,
            "ERC20: caller did not supply correct amount of FTM"
        );

        uint256[] memory tokenIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _mintERC721(_msgSender());
        }

        updateOracle();

        return tokenIds;
    }

    /**
     * @dev standard mint function that regular users call while
     * paying the appropriate mint fee to mint a ERC721
     */
    function mintWithToken() public whenNotPaused returns (uint256) {
        require(
            PAYMENT_TOKEN.allowance(_msgSender(), address(this)) >= MINTING_FEE,
            "ERC20: caller must provide approval to spend token"
        );

        PAYMENT_TOKEN.safeTransferFrom(
            _msgSender(),
            address(this),
            MINTING_FEE
        );

        return _mintERC721(_msgSender());
    }

    /**
     * @dev standard mint function that regular users call while
     * paying the appropriate mint fee to mint a number of ERC721s
     */
    function mintWithTokenCount(uint256 count)
        public
        whenNotPaused
        returns (uint256[] memory)
    {
        require(
            count <= MAX_TOKENS_PER_MINT,
            "ERC721: must mint less than the maximum count per mint"
        );

        uint256 totalMintingFee = MINTING_FEE * count;

        require(
            PAYMENT_TOKEN.allowance(_msgSender(), address(this)) >=
                totalMintingFee,
            "ERC20: caller must provide approval to spend token"
        );

        PAYMENT_TOKEN.safeTransferFrom(
            _msgSender(),
            address(this),
            totalMintingFee
        );

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
    function mintAdminCount(address _to, uint256 count)
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

        _constructRoyaltyReceiver(tokenId, _to);

        _safeMint(_to, tokenId);

        _setTokenRoyalty(
            tokenId,
            address(knownRoyaltyReceivers[tokenRoyaltyReceiver[tokenId]]),
            500
        ); // in basis points, 5%

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

    function setFTMPremium(uint96 _ftm_premium)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        FTM_PREMIUM = _ftm_premium;
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
     * @dev Generates a masked token URI so that people cannot guess what the next
     * NFT result will be
     */
    function _generateTokenURI(uint256 tokenId)
        internal
        view
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
        onlyRole(SERVICE_ROLE)
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

    /****** WITHDRAW METHODS ******/

    /**
     * @dev sends the full balance held by this contract to the caller
     */
    function withdraw() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(this).balance != 0, "contract has no balance");

        IPaymentSplitter splitter = IPaymentSplitter(PAYMENT_SPLITTER.clone());
        splitter.initialize();
        splitter.addPayee(_msgSender(), 90);

        if (_msgSender() != deployer) {
            splitter.addPayee(deployer, 10);
        }

        payable(address(splitter)).transfer(address(this).balance);
        splitter.releaseAll();
    }

    /**
     * @dev sends the full balance of the given token held by this contract to the caller
     */
    function withdraw(IERC20 token) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            token.balanceOf(address(this)) != 0,
            "contract has no balance of token"
        );

        IPaymentSplitter splitter = IPaymentSplitter(PAYMENT_SPLITTER.clone());
        splitter.initialize();
        splitter.addPayee(_msgSender(), 90);

        if (_msgSender() != deployer) {
            splitter.addPayee(deployer, 10);
        }

        token.safeTransfer(address(splitter), token.balanceOf(address(this)));
        splitter.releaseAll(address(token));
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
        if (tokenRoyaltyReceiver[tokenId] != address(0)) {
            knownRoyaltyReceivers[tokenRoyaltyReceiver[tokenId]].releaseAll();
        }

        baseRoyaltyReceiver.releaseAll();

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
