// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../libraries/Random.sol";
import "../interfaces/ISimpleRNG.sol";

contract SimpleRNG is ISimpleRNG {
    using Random for uint256;

    uint256 public constant VERSION = 2022042501;

    function getEntropy() public view returns (bytes32) {
        return Random.getEntropy();
    }

    function getRandom() public view returns (uint256) {
        return getRandom(type(uint256).max - 1);
    }

    function getRandom(uint256 maximumValue) public view returns (uint256) {
        return maximumValue.randomize(maximumValue);
    }

    function getRandom(uint256 maximumValue, bytes32 entropy) public view returns (uint256) {
        return maximumValue.randomizeWithEntropy(entropy, maximumValue);
    }
}
