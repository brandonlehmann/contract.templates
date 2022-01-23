// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IBondInformationHelper {
    function name(address _bond) external view returns (string memory);

    function symbol(address _bond) external view returns (string memory);
}
