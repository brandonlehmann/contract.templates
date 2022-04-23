// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../../@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "../Cloneable/Cloneable.sol";
import "../interfaces/IContract.Registry.sol";

interface IContract {
    function VERSION() external view returns (uint256);
}

contract ContractRegistry is Ownable, Cloneable, IContractRegistry {
    using Address for address;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    uint256 public constant VERSION = 2022042301;

    event ContractUpdated(string indexed name, address indexed _contract, uint256 indexed version);

    mapping(bytes32 => EnumerableMap.UintToAddressMap) private contracts;
    string[] public names;

    constructor() {
        _transferOwnership(address(0));
    }

    function add(string memory name, address _contract) public onlyOwner {
        require(_contract.isContract(), "Not a contract");
        uint256 version = IContract(_contract).VERSION();
        require(version != 0, "Contract must have version");
        bytes32 _hash = hash(name);
        require(!contracts[_hash].contains(version), "Contract version already registered");

        if (contracts[_hash].length() == 0) {
            names.push(name);
        }

        contracts[_hash].set(version, _contract);

        emit ContractUpdated(name, _contract, version);
    }

    function available() public view returns (string[] memory) {
        return names;
    }

    function get(string memory name) public view returns (address) {
        bytes32 _hash = hash(name);
        uint256 latestVersion = _latestVersion(_hash);
        require(latestVersion != 0, "Contract not registered");
        return contracts[_hash].get(latestVersion);
    }

    function get(string memory name, uint256 version) public view returns (address) {
        bytes32 _hash = hash(name);
        require(contracts[_hash].contains(version), "Contract version not registered");
        return contracts[_hash].get(version);
    }

    function get(bytes32 _hash) public view returns (address) {
        uint256 latestVersion = _latestVersion(_hash);
        require(latestVersion != 0, "Contract not registered");
        return contracts[_hash].get(latestVersion);
    }

    function get(bytes32 _hash, uint256 version) public view returns (address) {
        require(contracts[_hash].contains(version), "Contract version not registered");
        return contracts[_hash].get(version);
    }

    function hash(string memory value) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(value));
    }

    function initialize() public initializer {
        _transferOwnership(_msgSender());
    }

    function _latestVersion(bytes32 _hash) internal view returns (uint256) {
        uint256 latest = 0;
        for (uint256 i = 0; i < contracts[_hash].length(); i++) {
            (uint256 version, ) = contracts[_hash].at(i);
            if (version >= latest) {
                latest = version;
            }
        }
        return latest;
    }
}
