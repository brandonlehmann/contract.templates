// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IBlockTimeTracker.sol";

contract BlockTimeTracker is IBlockTimeTracker, Ownable {
    uint8 public constant PRECISION = 6;
    uint256 public startBlock;
    uint256 public startTimestamp;

    constructor() {
        startBlock = currentBlock();
        startTimestamp = currentTimestamp();
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

    function currentTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }

    function currentBlock() internal view returns (uint256) {
        return block.number;
    }

    /**
     * @dev returns the time weighted average blocks per second
     * PRECISION defines the number of digits required to represent
     * the fixed floating point representation of the value
     */
    function average() public view returns (uint256) {
        return
            divide(
                (currentBlock() - startBlock),
                (currentTimestamp() - startTimestamp),
                PRECISION
            );
    }

    /**
     * @dev resets the start block and start timestamp
     */
    function reset() public onlyOwner {
        startBlock = currentBlock();
        startTimestamp = currentTimestamp();
    }
}
