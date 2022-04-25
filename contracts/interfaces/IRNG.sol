// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IRNG {
    function getEntropy() external view returns (bytes32);

    function getRandom() external view returns (uint256);

    function getRandom(uint256 maximumValue) external view returns (uint256);

    function getRandom(uint256 maximumValue, bytes32 entropy) external view returns (uint256);
}
