// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IInterestCalculator {
    function calculate(
        uint256 P,
        uint256 r,
        uint256 n,
        uint256 t
    ) external returns (uint256);

    function calculate_interest_multiplier(
        uint256 r,
        uint256 n,
        uint256 t
    ) external returns (uint256);
}
