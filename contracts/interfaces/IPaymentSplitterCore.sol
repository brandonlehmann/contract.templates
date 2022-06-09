// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/access/IOwnable.sol";

interface IPaymentSplitterCore is IOwnable {
    function addPayee(address payee, uint256 shares) external;

    function clone() external returns (address);

    function count() external view returns (uint256);

    function initialize() external;

    function initialize(address[] memory payees, uint256[] memory shares) external;

    function payees(uint256 index) external returns (address);

    function shares(address payee) external view returns (uint256);

    function totalShares() external view returns (uint256);

    function VERSION() external view returns (uint256);
}
