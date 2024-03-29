// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IPaymentSplitter.sol";

interface IRoyaltyManager {
    function PAYMENT_SPLITTER() external view returns (IPaymentSplitter);

    function clone() external returns (address);

    function baseRoyaltyReceiver() external view returns (IPaymentSplitter);

    function knownRoyaltyReceivers(address account) external view returns (IPaymentSplitter);

    function tokenRoyaltyReceiver(uint256 tokenId) external view returns (address);

    function initialize() external;

    function initialize(address[] memory accounts, uint256[] memory shares) external;

    function add(
        uint256 tokenId,
        uint256 shares1,
        address account2,
        uint256 shares2
    ) external returns (address);

    function releaseAll(uint256 tokenId) external;

    function releaseAll(uint256 tokenId, address token) external;

    function VERSION() external view returns (uint256);
}
