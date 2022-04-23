// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/proxy/Clones.sol";
import "../../@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/ICloneable.sol";

abstract contract Cloneable is ICloneable, Initializable {
    using Clones for address;

    event CloneDeployed(address indexed parent, address indexed clone, bytes32 indexed salt);

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone() public returns (address instance) {
        if (address(this).code.length > 45) {
            instance = address(this).clone();
            emit CloneDeployed(address(this), instance, 0x0);
        } else {
            instance = ICloneable(parent()).clone();
            emit CloneDeployed(parent(), instance, 0x0);
        }
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(bytes32 salt) public returns (address instance) {
        if (address(this).code.length > 45) {
            instance = address(this).cloneDeterministic(salt);
            emit CloneDeployed(address(this), instance, salt);
        } else {
            instance = ICloneable(parent()).cloneDeterministic(salt);
            emit CloneDeployed(parent(), instance, salt);
        }
    }

    /**
     * @dev Returns if this contract is a clone
     */
    function isClone() public view returns (bool) {
        return (address(this).code.length == 45);
    }

    /**
     * @dev Returns the parent contract address or self if the parent
     */
    function parent() public view returns (address) {
        if (address(this).code.length > 45) {
            return address(this);
        } else {
            bytes memory _parent = new bytes(20);
            address master;

            uint256 k = 0;
            for (uint256 i = 10; i <= 29; i++) {
                _parent[k++] = address(this).code[i];
            }

            assembly {
                master := mload(add(_parent, 20))
            }

            return master;
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(bytes32 salt) public view returns (address instance) {
        if (address(this).code.length > 45) {
            instance = address(this).predictDeterministicAddress(salt);
        } else {
            instance = ICloneable(parent()).predictDeterministicAddress(salt);
        }
    }
}
