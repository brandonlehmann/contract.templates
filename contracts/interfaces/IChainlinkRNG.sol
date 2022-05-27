// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IRNG.sol";

interface IChainlinkRNG is IRNG {
    function addFeed(address feed) external;

    function clone() external returns (address);

    function feeds(uint256) external view returns (address);

    function initialize() external;

    function VERSION() external view returns (uint256);
}
