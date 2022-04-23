// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./ICloneable.sol";

interface ISimpleRNG is ICloneable {
    function addFeed(address feed) external;

    function feeds(uint256) external view returns (address);

    function getEntropy() external view returns (bytes32);

    function getRandom() external view returns (bytes32);

    function getRandom(uint256 seed) external view returns (bytes32);

    function initialize() external;

    function VERSION() external view returns (uint256);
}
