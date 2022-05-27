// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../Cloneable/Cloneable.sol";
import "../interfaces/IChainlinkRNG.sol";
import "../libraries/Random.sol";

contract ChainlinkRNG is IChainlinkRNG, Cloneable, Ownable {
    using Random for uint256;

    uint256 public constant VERSION = 2022042501;

    address[] public feeds;

    constructor() {
        _transferOwnership(address(0));
    }

    function addFeed(address feed) public onlyOwner {
        require(AggregatorV3Interface(feed).version() != 0, "Does not appear to be a chainlink feed");
        feeds.push(feed);
    }

    function clone() public returns (address) {
        return _clone();
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

    function getRandom() public view returns (uint256) {
        return getRandom(type(uint256).max - 1);
    }

    function getRandom(uint256 maximumValue) public view returns (uint256) {
        return maximumValue.randomizeWithEntropy(getEntropy());
    }

    function getRandom(uint256 maximumVale, bytes32 entropy) public view returns (uint256) {
        return maximumVale.randomizeWithEntropy(keccak256(abi.encodePacked(entropy, getEntropy())));
    }

    function initialize() public initializer {
        _transferOwnership(_msgSender());
    }
}
