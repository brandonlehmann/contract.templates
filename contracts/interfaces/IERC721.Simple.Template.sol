// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";

interface IERC721SimpleTemplate is IERC721Enumerable {
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 _max_supply,
        uint256 _max_tokens_per_mint,
        address _royalty_receiver,
        uint96 _royalty_basis_points
    ) external;

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function VERSION() external view returns (uint256);

    function MAX_SUPPLY() external view returns (uint256);

    function pause() external;

    function unpause() external;

    function mint(uint256 count) external payable returns (uint256[] memory);

    function adminMint(address _to, uint256 count)
        external
        returns (uint256[] memory);

    function setBaseURI(string memory) external;

    function setURIExtension(string memory) external;
}
