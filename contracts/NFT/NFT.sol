// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../ERC721.Template/ERC721.Template.sol";

contract NFT is ERC721Template {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}
}
