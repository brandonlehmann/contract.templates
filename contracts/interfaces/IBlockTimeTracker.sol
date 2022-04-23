// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./ICloneable.sol";

interface IBlockTimeTracker is ICloneable {
    function initialize() external;

    function startBlock() external view returns (uint256);

    function startTimestamp() external view returns (uint256);

    function average(uint8 precision) external view returns (uint256);

    function reset() external;

    function VERSION() external view returns (uint256);
}
