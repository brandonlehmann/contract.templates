// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "../../@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IERC721.Simple.Template.sol";

contract ERC721SimpleTemplate is
    IERC721SimpleTemplate,
    ERC721Enumerable,
    ERC721Royalty,
    ERC721Pausable,
    Ownable,
    Initializable
{
    using Strings for uint256;

    uint256 public constant VERSION = 2022021601;

    // fee settings
    uint256 public MAX_SUPPLY = 0;
    uint256 public MAX_TOKENS_PER_MINT = 1;

    // URI settings
    string private BASE_URI = "";
    string private URI_EXTENSION = ".json";

    constructor() ERC721("", "") {}

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 _max_supply,
        uint256 _max_tokens_per_mint,
        address _royalty_receiver,
        uint96 _royalty_basis_points
    ) public initializer {
        require(_max_supply >= 1, "Max supply must be at least 1");
        _name = name_;
        _symbol = symbol_;

        MAX_SUPPLY = _max_supply;
        MAX_TOKENS_PER_MINT = _max_tokens_per_mint;

        _setDefaultRoyalty(_royalty_receiver, _royalty_basis_points);
    }

    function pause() public onlyOwner whenInitialized {
        _pause();
    }

    function unpause() public onlyOwner whenInitialized {
        _unpause();
    }

    function mint(uint256 count) public payable virtual whenNotPaused whenInitialized returns (uint256[] memory) {
        count;
        revert("not implemented");
    }

    function adminMint(address _to, uint256 count)
        public
        virtual
        onlyOwner
        overridePause
        whenInitialized
        returns (uint256[] memory)
    {
        require(count != 0, "ERC20: must mint at least one");
        require(count <= MAX_TOKENS_PER_MINT, "ERC721: max tokens per mint exceeded");

        uint256[] memory tokenIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _mintNFT(_to);
        }

        return tokenIds;
    }

    function _mintNFT(address _to) internal returns (uint256) {
        uint256 supply = totalSupply();
        require(supply + 1 <= MAX_SUPPLY, "ERC721: Mint Complete");
        uint256 tokenId = supply + 1;

        _safeMint(_to, tokenId);

        return tokenId;
    }

    function setBaseURI(string memory _base_uri) public onlyOwner whenInitialized {
        BASE_URI = _base_uri;
    }

    function setURIExtension(string memory _uri_extension) public onlyOwner whenInitialized {
        URI_EXTENSION = _uri_extension;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, IERC721SimpleTemplate) returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        return string(abi.encodePacked(BASE_URI, tokenId.toString(), URI_EXTENSION));
    }

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
        super._afterTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721Royalty) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable, ERC721Royalty, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
