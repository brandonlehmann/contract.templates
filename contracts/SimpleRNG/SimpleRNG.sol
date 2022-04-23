// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../Cloneable/Cloneable.sol";
import "../interfaces/ISimpleRNG.sol";

contract SimpleRNG is ISimpleRNG, Cloneable, Ownable {
    uint256 public constant VERSION = 2022042301;

    address[] public feeds;

    constructor() {
        _transferOwnership(address(0));
    }

    function addFeed(address feed) public onlyOwner {
        require(AggregatorV3Interface(feed).version() != 0, "Does not appear to be a chainlink feed");
        feeds.push(feed);
    }

    function getEntropy() public view returns (bytes32) {
        bytes32[] memory tmp = new bytes32[](feeds.length);

        for (uint8 i = 0; i < feeds.length; i++) {
            (
                uint80 roundId,
                int256 answer,
                uint256 startedAt,
                uint256 updatedAt,
                uint80 answeredInRound
            ) = AggregatorV3Interface(feeds[i]).latestRoundData();
            tmp[i] = keccak256(abi.encodePacked(roundId, answer, startedAt, updatedAt, answeredInRound));
        }

        return keccak256(abi.encodePacked(address(this), tmp));
    }

    function getRandom() public view returns (bytes32) {
        return keccak256(abi.encodePacked(getEntropy(), block.number, block.timestamp, msg.sender, block.difficulty));
    }

    function getRandom(uint256 seed) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(getEntropy(), block.number, block.timestamp, msg.sender, block.difficulty, seed)
            );
    }

    function initialize() public initializer {
        _transferOwnership(_msgSender());
    }
}
