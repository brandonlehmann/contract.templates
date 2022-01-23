// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@solidity-lib/contracts/libraries/FixedPoint.sol";

interface IUniswapV2TWAPOracle {
    function PERIOD() external view returns (uint256);

    struct LastValue {
        address token0;
        address token1;
        uint256 price0Cumulative;
        uint256 price1Cumulative;
        uint32 blockTimestamp;
        FixedPoint.uq112x112 price0Average;
        FixedPoint.uq112x112 price1Average;
    }

    function consult(
        address pair,
        address token,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function lastValue(address pair) external view returns (LastValue memory);

    function update(address pair) external;

    function updateAll() external;
}
