// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/IBlockTimeTracker.sol";
import "../interfaces/IDAOInformationHelper.sol";

interface IStakingContract {
    struct Epoch {
        uint256 length;
        uint256 number;
        uint256 endBlock;
        uint256 distribute;
    }

    function epoch() external view returns (Epoch memory);

    function index() external view returns (uint256);
}

interface IStakedToken is IERC20Metadata {
    function circulatingSupply() external view returns (uint256);
}

contract DAOInformationHelper is IDAOInformationHelper {
    function info(
        address stakingContract,
        address stakedToken,
        address timeTracker,
        address stakingWallet
    )
        public
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
        )
    {
        IStakingContract.Epoch memory epoch = IStakingContract(stakingContract).epoch();

        epochNumber = epoch.number;
        epochLength = epoch.length;
        epochEndBlock = epoch.endBlock;
        epochDistribute = epoch.distribute;
        blockNumber = block.number;
        stakingIndex = IStakingContract(stakingContract).index();
        stakedDecimals = IStakedToken(stakedToken).decimals();
        stakedCirculatingSupply = IStakedToken(stakedToken).circulatingSupply();
        blockAverage = IBlockTimeTracker(timeTracker).average(6);
        blockPrecision = 6;
        stakingBalance = IStakedToken(stakedToken).balanceOf(stakingWallet);
    }
}
