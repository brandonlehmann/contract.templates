// SPDX-License-Identifier: MIT
// Brandon Lehmann <brandonlehmann@gmail.com>

pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/proxy/Clones.sol";
import "../../@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/ICloneable.sol";

abstract contract Cloneable is ICloneable, Initializable {
    using Clones for address;

    event CloneDeployed(address indexed deployer, address indexed progenitor, address indexed clone, bytes32 salt);

    address public immutable progenitor;

    modifier isCloned() {
        require(address(this) != progenitor, "Cloneable: Contract is not a clone");
        _;
    }

    constructor() {
        progenitor = address(this);
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone() public returns (address instance) {
        instance = progenitor.clone();
        emit CloneDeployed(msg.sender, progenitor, instance, 0x0);
        _afterClone(msg.sender, progenitor, instance, 0x0);
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(bytes32 salt) public returns (address instance) {
        instance = progenitor.cloneDeterministic(salt);
        emit CloneDeployed(msg.sender, progenitor, instance, salt);
        _afterClone(msg.sender, progenitor, instance, salt);
    }

    /**
     * @dev Returns if this contract is a clone
     */
    function isClone() public view returns (bool) {
        return address(this) != progenitor;
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(bytes32 salt) public view returns (address instance) {
        instance = progenitor.predictDeterministicAddress(salt);
    }

    /**
     * @dev hook that is ran after cloning
     */
    function _afterClone(
        address deployer,
        address _progenitor,
        address _clone,
        bytes32 salt
    ) internal virtual {}
}
