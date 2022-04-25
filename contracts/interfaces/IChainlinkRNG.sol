// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./ICloneable.sol";
import "./IRNG.sol";

interface IChainlinkRNG is ICloneable, IRNG {
    function addFeed(address feed) external;

    function feeds(uint256) external view returns (address);

    function initialize() external;

    function VERSION() external view returns (uint256);
}
