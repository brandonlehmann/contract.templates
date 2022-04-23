// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./ICloneable.sol";

interface IContractRegistry is ICloneable {
    function add(string memory name, address _contract) external;

    function available() external view returns (string[] memory);

    function get(string memory name) external view returns (address);

    function get(string memory name, uint256 version) external view returns (address);

    function get(bytes32 _hash) external view returns (address);

    function get(bytes32 _hash, uint256 version) external view returns (address);

    function hash(string memory name) external pure returns (bytes32);

    function initialize() external;

    function VERSION() external view returns (uint256);
}

// Added after deployment to mainnet
IContractRegistry constant FTMContractRegistry = IContractRegistry(0xF053aC89d18b3151984fD94368296805A7bDa92F);
