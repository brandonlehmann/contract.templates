// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ICloneable {
    function clone() external returns (address);

    function cloneDeterministic(bytes32 salt) external returns (address);

    function isClone() external view returns (bool);

    function predictDeterministicAddress(bytes32 salt) external view returns (address);

    function progenitor() external view returns (address);
}
