// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ILockable {
    function locked() external view returns (bool);
}
