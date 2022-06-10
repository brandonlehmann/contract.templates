// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../abstracts/ERC721.Omnichain.sol";

contract ERC721Mock is ERC721Omnichain {
    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
        LzApp(address(0))
        ClampedRandomizer(10000)
    {}

    function mint() public returns (uint256) {
        uint256 tokenId = totalSupply() + 1;

        _safeMint(_msgSender(), tokenId);

        return tokenId;
    }
}
