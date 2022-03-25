// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ISimpleRNG {
    function getEntropy() external view returns (bytes32);

    function getRandom() external view returns (bytes32);

    function getRandom(uint256 seed) external view returns (bytes32);
}
