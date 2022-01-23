// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IWalletAggregator {
    function add(address _wallet) external;

    function balanceOf(address _token) external view returns (uint256);

    function remove(address _wallet) external;

    function transfer(address _token) external returns (uint256);

    function withdraw() external;

    function withdraw(address _token) external;
}
