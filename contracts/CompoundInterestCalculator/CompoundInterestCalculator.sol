// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../libraries/FastFixedExponent.sol";

contract CompoundInterestCalculator {
    using FastFixedExponent for uint256;

    // P = principal balance
    // r = interest rate in bps (500 = 5%)
    // n = number of periods
    // t = the number of periods compounded
    //
    // returns the total amount in the base unit(s) of the principal
    function calculate(
        uint256 P,
        uint256 r,
        uint256 n,
        uint256 t
    ) public pure returns (uint256) {
        return (P * calculate_interest_multiplier(r, n, t)) / 10**18; // P*(1+(r/n))^t
    }

    // r = interest rate in bps (500 = 5%)
    // n = number of periods
    // t = the number of periods compounded
    //
    // returns the compounded multiplier in 18-decimals
    function calculate_interest_multiplier(
        uint256 r,
        uint256 n,
        uint256 t
    ) public pure returns (uint256) {
        return ((1 * 10**18) + (((r * 10**18) / 10000) / n)).pow(t); // (1+(r/n))^t
    }
}
