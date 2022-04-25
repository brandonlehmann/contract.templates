// SPDX-License-Identifier: MIT
// Brandon Lehmann <brandonlehmann@gmail.com>

pragma solidity ^0.8.10;

library Random {
    /**
     * @dev Generates a random value within the range of the value
     */
    function randomize(uint256 value) internal view returns (uint256) {
        return randomizeWithEntropy(value, getEntropy(), value);
    }

    /**
     * @dev Generates a random value within the range of the specified maximum value
     */
    function randomize(uint256 value, uint256 maximumValue) internal view returns (uint256) {
        return randomizeWithEntropy(value, getEntropy(), maximumValue);
    }

    /**
     * @dev Generates a random value within the range of the value using the supplied entropy
     */
    function randomizeWithEntropy(uint256 value, bytes32 entropy) internal view returns (uint256) {
        return randomizeWithEntropy(value, entropy, value);
    }

    /**
     * @dev Generates a random value within the range of the specified maximum value using the supplied entropy
     */
    function randomizeWithEntropy(
        uint256 value,
        bytes32 entropy,
        uint256 maximumValue
    ) internal view returns (uint256) {
        return _getEntropy(value, entropy) % maximumValue;
    }

    /**
     * @dev Generates simple on-chain entropy
     */
    function getEntropy() internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    address(this),
                    msg.sender,
                    block.coinbase,
                    block.number,
                    block.timestamp,
                    block.difficulty,
                    msg.data
                )
            );
    }

    /**
     * @dev Generates simple on-chain entropy that is seeded with the supplied entropy
     */
    function _getEntropy(uint256 value, bytes32 entropy) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(getEntropy(), value, entropy)));
    }
}
