// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../../@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IChainlinkRegistry.sol";

contract ChainlinkRegistry is IChainlinkRegistry, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    ChainlinkFeed[] private chainlinkFeeds;

    mapping(string => uint256) private feedByName;
    mapping(address => uint256) private feedByAsset;
    mapping(address => uint256) private feedByFeed;
    EnumerableSet.AddressSet private feeds;

    event AddFeed(
        string indexed name,
        address indexed asset,
        address indexed feed
    );
    event RemoveFeed(
        string indexed name,
        address indexed assset,
        address indexed feed
    );

    function add(
        string memory name,
        address feed,
        address asset
    ) public onlyOwner {
        require(
            !feeds.contains(feed),
            "ChainlinkRegistry: feed already exists"
        );
        require(
            AggregatorV3Interface(feed).version() != 0 &&
                AggregatorV3Interface(feed).decimals() != 0,
            "AggregatorV3Interface: feed does not appear to be a chainlink feed"
        );
        require(
            feedByName[name] == 0,
            "ChainlinkRegistry: feed already exists for name"
        );

        if (asset != address(0)) {
            require(
                feedByAsset[asset] == 0,
                "ChainlinkRegistry: feed already exists for asset"
            );
            require(
                IERC20Metadata(asset).decimals() != 0,
                "ERC721Metadata: token does not appear to be an ERC20"
            );
        }

        uint256 index = chainlinkFeeds.length;

        chainlinkFeeds.push(
            ChainlinkFeed({name: name, asset: asset, feed: feed})
        );

        feedByName[name] = index;
        if (asset != address(0)) {
            feedByAsset[asset] = index;
        }
        feedByFeed[feed] = index;
        feeds.add(feed);

        emit AddFeed(name, asset, feed);
    }

    function count() public view returns (uint256) {
        return feeds.length();
    }

    function getFeed(uint256 index) public view returns (ChainlinkFeed memory) {
        return chainlinkFeeds[index];
    }

    function getFeed(string memory name)
        public
        view
        returns (ChainlinkFeed memory)
    {
        ChainlinkFeed memory info = chainlinkFeeds[feedByName[name]];

        require(
            keccak256(abi.encodePacked(info.name)) ==
                keccak256(abi.encodePacked(name)),
            "ChainlinkRegistry: cannot locate feed by name"
        );

        return info;
    }

    function getFeed(address asset) public view returns (ChainlinkFeed memory) {
        ChainlinkFeed memory info = chainlinkFeeds[feedByAsset[asset]];

        require(
            info.asset == asset,
            "ChainlinkRegistry: cannot locate feed by asset"
        );

        return info;
    }

    function remove(address feed) public onlyOwner {
        require(feeds.contains(feed), "ChainlinkRegistry: feed does not exist");

        uint256 index = feedByFeed[feed];

        ChainlinkFeed memory info = chainlinkFeeds[index];

        delete feedByName[info.name];
        delete feedByFeed[feed];
        delete feedByAsset[info.asset];
        feeds.remove(feed);
        delete chainlinkFeeds[index];

        emit RemoveFeed(info.name, info.asset, info.feed);
    }
}
