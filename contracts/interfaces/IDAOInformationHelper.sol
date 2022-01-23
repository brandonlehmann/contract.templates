// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IDAOInformationHelper {
    function info(
        address stakingContract,
        address stakedToken,
        address timeTracker,
        address stakingWallet
    )
        external
        view
        returns (
            uint256 epochNumber,
            uint256 epochLength,
            uint256 epochEndBlock,
            uint256 epochDistribute,
            uint256 blockNumber,
            uint256 stakingIndex,
            uint8 stakedDecimals,
            uint256 stakedCirculatingSupply,
            uint256 blockAverage,
            uint8 blockPrecision,
            uint256 stakingBalance
        );
}
