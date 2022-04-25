// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IRNG.sol";

interface ISimpleRNG is IRNG {
    function VERSION() external view returns (uint256);
}
