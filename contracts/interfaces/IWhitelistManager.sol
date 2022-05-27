// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IWhitelistManager {
    function initialize() external;

    function add(address account, uint256 _count) external returns (bool);

    function clone() external returns (address);

    function check(address account) external view returns (bool _exists, uint256 _count);

    function contains(address account) external view returns (bool);

    function count() external view returns (uint256);

    function decrement(address account) external;

    function decrement(address account, uint256 _count) external;

    function entry(address account) external view returns (address _account, uint256 _count);

    function entry(uint256 index) external view returns (address _account, uint256 _count);

    function pause() external;

    function paused() external view returns (bool);

    function remaining(address account) external view returns (uint256);

    function remove(address account) external returns (bool);

    function unpause() external;

    function values() external returns (address[] memory);

    function VERSION() external view returns (uint256);
}
