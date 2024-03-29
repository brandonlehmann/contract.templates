// SPDX-License-Identifier: MIT
// Brandon Lehmann <brandonlehmann@gmail.com>

pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/proxy/Clones.sol";
import "../../@openzeppelin/contracts/proxy/utils/Initializable.sol";

abstract contract Cloneable is Initializable {
    using Clones for address;

    event CloneDeployed(address indexed deployer, address indexed progenitor, address indexed clone, bytes32 salt);

    address internal immutable progenitor;

    modifier isCloned() {
        require(address(this) != progenitor, "Cloneable: Contract is not a clone");
        _;
    }

    constructor() {
        progenitor = address(this);
    }

    /**
     * @dev Returns if this contract is a clone
     */
    function isClone() public view returns (bool) {
        return address(this) != progenitor;
    }

    /****** INTERNAL METHODS ******/

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function _clone() internal returns (address instance) {
        _beforeClone(msg.sender, progenitor, instance, 0x0);
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
    function _cloneDeterministic(bytes32 salt) internal returns (address instance) {
        _beforeClone(msg.sender, progenitor, instance, salt);
        instance = progenitor.cloneDeterministic(salt);
        emit CloneDeployed(msg.sender, progenitor, instance, salt);
        _afterClone(msg.sender, progenitor, instance, salt);
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function _predictDeterministicAddress(bytes32 salt) internal view returns (address instance) {
        instance = progenitor.predictDeterministicAddress(salt);
    }

    /**
     * @dev hook that is ran before cloning
     */
    function _beforeClone(
        address deployer,
        address _progenitor,
        address clone_,
        bytes32 salt
    ) internal virtual {}

    /**
     * @dev hook that is ran after cloning
     */
    function _afterClone(
        address deployer,
        address _progenitor,
        address clone_,
        bytes32 salt
    ) internal virtual {}
}
