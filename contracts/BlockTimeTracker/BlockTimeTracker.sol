// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../Cloneable/Cloneable.sol";
import "../interfaces/IBlockTimeTracker.sol";

contract BlockTimeTracker is IBlockTimeTracker, Cloneable, Ownable {
    uint256 public constant VERSION = 2022042301;
    uint256 public startBlock = 0;
    uint256 public startTimestamp = 0;

    constructor() {
        _transferOwnership(address(0));
    }

    function initialize() public initializer {
        startBlock = block.number;
        startTimestamp = block.timestamp;

        _transferOwnership(_msgSender());
    }

    /**
     * @dev internal method that does quick division using the set precision
     */
    function divide(
        uint256 a,
        uint256 b,
        uint8 precision
    ) internal pure returns (uint256) {
        return (a * (10**precision)) / b;
    }

    /**
     * @dev returns the time weighted average blocks per second
     * PRECISION defines the number of digits required to represent
     * the fixed floating point representation of the value
     */
    function average(uint8 precision) public view returns (uint256) {
        return divide((block.number - startBlock), (block.timestamp - startTimestamp), precision);
    }

    /**
     * @dev resets the start block and start timestamp
     */
    function reset() public onlyOwner whenInitialized {
        startBlock = block.number;
        startTimestamp = block.timestamp;
    }
}
