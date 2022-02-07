// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IUniswapV2TWAPOracle {
    function PERIOD() external view returns (uint256);

    function consult(
        address pair,
        address token,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function consultCurrent(
        address pair,
        address token,
        uint256 amountIn
    ) external view returns (uint256);

    function update(address pair) external;

    function updateAll() external;
}
