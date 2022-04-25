// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./ICloneable.sol";

interface IContractRegistry is ICloneable {
    function add(string memory name, address _contract) external;

    function available() external view returns (string[] memory);

    function get(bytes memory value) external view returns (address);

    function get(bytes memory value, uint256 version) external view returns (address);

    function getByName(string memory name) external view returns (address);

    function getByName(string memory name, uint256 version) external view returns (address);

    function getByHash(bytes32 _hash) external view returns (address);

    function getByHash(bytes32 _hash, uint256 version) external view returns (address);

    function initialize() external;

    function VERSION() external view returns (uint256);
}

// Added after deployment to mainnet
IContractRegistry constant FTMContractRegistry = IContractRegistry(0xF053aC89d18b3151984fD94368296805A7bDa92F);
