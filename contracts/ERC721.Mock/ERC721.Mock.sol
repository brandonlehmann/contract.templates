// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../../@openzeppelin/contracts/access/Ownable.sol";

contract ERC721Mock is ERC721Enumerable, Ownable {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint() public onlyOwner returns (uint256) {
        uint256 supply = totalSupply();

        uint256 tokenId = supply + 1;

        _safeMint(_msgSender(), tokenId);

        return tokenId;
    }
}
