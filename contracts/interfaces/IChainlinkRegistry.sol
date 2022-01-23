// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IChainlinkRegistry {
    struct ChainlinkFeed {
        string name;
        address asset;
        address feed;
    }

    function add(
        string memory name,
        address feed,
        address asset
    ) external;

    function count() external view returns (uint256);

    function getFeed(uint256 index)
        external
        view
        returns (ChainlinkFeed memory);

    function getFeed(string memory name)
        external
        view
        returns (ChainlinkFeed memory);

    function getFeed(address asset)
        external
        view
        returns (ChainlinkFeed memory);

    function remove(address feed) external;
}
