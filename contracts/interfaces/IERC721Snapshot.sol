// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./ICloneable.sol";

interface IERC721Snapshot is ICloneable {
    function completed() external view returns (bool);

    function initialize() external;

    function initialize(IERC721Enumerable ERC721Contract) external;

    function holders(uint256 index) external view returns (address);

    function length() external view returns (uint256);

    function snapshot(uint256 maxCount) external returns (bool);

    function VERSION() external view returns (uint256);
}
