// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/proxy/Clones.sol";
import "../../@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/ICloneable.sol";

abstract contract Cloneable is ICloneable, Initializable {
    using Clones for address;

    event CloneDeployed(address indexed deployer, address indexed parent, address indexed clone, bytes32 salt);

    address public immutable parent;
    bytes32 public constant CLONE_DEPLOYED_TOPIC = keccak256("CloneDeployed(address,address,address,bytes32)");

    constructor() {
        parent = address(this);
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone() public returns (address instance) {
        instance = parent.clone();
        emit CloneDeployed(msg.sender, parent, instance, 0x0);
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(bytes32 salt) public returns (address instance) {
        instance = parent.cloneDeterministic(salt);
        emit CloneDeployed(msg.sender, parent, instance, salt);
    }

    /**
     * @dev Returns if this contract is a clone
     */
    function isClone() public view returns (bool) {
        return address(this) != parent;
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(bytes32 salt) public view returns (address instance) {
        instance = parent.predictDeterministicAddress(salt);
    }
}
