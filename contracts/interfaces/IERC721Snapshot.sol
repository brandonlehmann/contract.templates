// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IERC721Snapshot {
    function initialize(IERC721Enumerable ERC721Contract) external;

    function holders(uint256 index) external view returns (address);

    function length() external view returns (uint256);
}
