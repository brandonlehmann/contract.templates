// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IBlockTimeTracker {
    function PRECISION() external view returns (uint8);

    function startBlock() external view returns (uint256);

    function startTimestamp() external view returns (uint256);

    function average() external view returns (uint256);

    function reset() external;

    function VERSION() external view returns (uint256);
}
