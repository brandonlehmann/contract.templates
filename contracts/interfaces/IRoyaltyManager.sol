// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IRoyaltyManager {
    function baseRoyaltyReceiver() external view returns (address);

    function knownRoyaltyReceivers(address account) external view returns (address);

    function tokenRoyaltyReceiver(uint256 tokenId) external view returns (address);

    function initialize(
        address account1,
        uint256 shares1,
        address account2,
        uint256 shares2
    ) external;

    function add(
        uint256 tokenId,
        uint256 shares1,
        address account2,
        uint256 shares2
    ) external returns (address);

    function cloneSplitter() external returns (address);

    function releaseAll(uint256 tokenId) external;

    function releaseAll(uint256 tokenId, address token) external;

    function VERSION() external view returns (uint256);
}
