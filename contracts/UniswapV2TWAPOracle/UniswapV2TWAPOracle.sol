// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@solidity-lib/contracts/libraries/FixedPoint.sol";
import "../../@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../../@uniswap-v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2TWAPOracle.sol";

/**
See https://github.com/Uniswap/v2-periphery/blob/master/contracts/examples/ExampleOracleSimple.sol
for the basis for the below contract. ExampleOracleSimple contract has been extended to support tracking multiple
pairs within the same contract.
*/

contract UniswapV2TWAPOracle is IUniswapV2TWAPOracle, Ownable {
    using FixedPoint for *;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct LastValue {
        address token0;
        address token1;
        uint256 price0Cumulative;
        uint256 price1Cumulative;
        uint32 blockTimestamp;
        FixedPoint.uq112x112 price0Average;
        FixedPoint.uq112x112 price1Average;
    }

    event AddPair(
        address indexed pair,
        address indexed token0,
        address indexed token1
    );
    event RemovePair(
        address indexed pair,
        address indexed token0,
        address indexed token1
    );
    event UpdatedValues(
        address indexed pair,
        FixedPoint.uq112x112 price0Average,
        FixedPoint.uq112x112 price1Average,
        uint256 price0Cumulative,
        uint256 price1Cumulative,
        uint32 blockTimestamp
    );

    uint256 public constant PERIOD = 5 minutes;

    mapping(address => LastValue) private _lastValues;
    EnumerableSet.AddressSet private pairs;

    function addPair(address pair) public onlyOwner {
        require(!pairs.contains(pair), "PAIR_ALREADY_EXISTS");

        IUniswapV2Pair _pair = IUniswapV2Pair(pair);

        (uint256 reserve0, uint256 reserve1, uint32 blockTimestampLast) = _pair
            .getReserves();

        require(reserve0 != 0 && reserve1 != 0, "NO_RESERVES");

        _lastValues[pair] = LastValue({
            token0: _pair.token0(),
            token1: _pair.token1(),
            price0Cumulative: _pair.price0CumulativeLast(),
            price1Cumulative: _pair.price1CumulativeLast(),
            blockTimestamp: blockTimestampLast,
            price0Average: type(uint112).min.encode(),
            price1Average: type(uint112).min.encode()
        });

        pairs.add(pair);

        emit AddPair(pair, _pair.token0(), _pair.token1());
    }

    // returns the the amount of other tokens for the tokens specified
    function consult(
        address pair,
        address token,
        uint256 amountIn
    ) public view override returns (uint256 amountOut) {
        LastValue memory _lastValue = _lastValues[pair];

        if (token == _lastValue.token0) {
            amountOut = _lastValue.price0Average.mul(amountIn).decode144();
        } else {
            require(token == _lastValue.token1, "INVALID_TOKEN");
            amountOut = _lastValue.price1Average.mul(amountIn).decode144();
        }
    }

    function consultCurrent(
        address pair,
        address token,
        uint256 amountIn
    ) public view returns (uint256 amountOut) {
        LastValue memory _lastValue = _lastValues[pair];

        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = currentCumulativePrices(pair);
        uint32 timeElapsed = blockTimestamp - _lastValue.blockTimestamp;

        // ensure that at least one full period has passed since the last update
        if (timeElapsed < PERIOD) {
            return consult(pair, token, amountIn);
        }

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        _lastValue.price0Average = FixedPoint.uq112x112(
            uint224(
                (price0Cumulative - _lastValue.price0Cumulative) / timeElapsed
            )
        );
        _lastValue.price1Average = FixedPoint.uq112x112(
            uint224(
                (price1Cumulative - _lastValue.price1Cumulative) / timeElapsed
            )
        );

        _lastValue.price0Cumulative = price0Cumulative;
        _lastValue.price1Cumulative = price1Cumulative;
        _lastValue.blockTimestamp = blockTimestamp;

        if (token == _lastValue.token0) {
            amountOut = _lastValue.price0Average.mul(amountIn).decode144();
        } else {
            require(token == _lastValue.token1, "INVALID_TOKEN");
            amountOut = _lastValue.price1Average.mul(amountIn).decode144();
        }
    }

    // helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2**32);
    }

    // produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices(address pair)
        internal
        view
        returns (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        )
    {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = IUniswapV2Pair(pair).price0CumulativeLast();
        price1Cumulative = IUniswapV2Pair(pair).price1CumulativeLast();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        ) = IUniswapV2Pair(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            // subtraction overflow is desired
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            // addition overflow is desired
            // counterfactual
            price0Cumulative +=
                uint256(FixedPoint.fraction(reserve1, reserve0)._x) *
                timeElapsed;
            // counterfactual
            price1Cumulative +=
                uint256(FixedPoint.fraction(reserve0, reserve1)._x) *
                timeElapsed;
        }
    }

    function lastValue(address pair) public view returns (LastValue memory) {
        return _lastValues[pair];
    }

    function removePair(address pair) public onlyOwner {
        require(pairs.contains(pair), "PAIR_DOES_NOT_EXIST");
        LastValue memory old = _lastValues[pair];
        pairs.remove(pair);
        delete _lastValues[pair];
        emit RemovePair(pair, old.token0, old.token1);
    }

    function update(address pair) public override {
        LastValue memory _lastValue = _lastValues[pair];

        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = currentCumulativePrices(pair);
        uint32 timeElapsed = blockTimestamp - _lastValue.blockTimestamp;

        // ensure that at least one full period has passed since the last update
        if (timeElapsed < PERIOD) {
            return;
        }

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        _lastValue.price0Average = FixedPoint.uq112x112(
            uint224(
                (price0Cumulative - _lastValue.price0Cumulative) / timeElapsed
            )
        );
        _lastValue.price1Average = FixedPoint.uq112x112(
            uint224(
                (price1Cumulative - _lastValue.price1Cumulative) / timeElapsed
            )
        );

        _lastValue.price0Cumulative = price0Cumulative;
        _lastValue.price1Cumulative = price1Cumulative;
        _lastValue.blockTimestamp = blockTimestamp;

        _lastValues[pair] = _lastValue;

        emit UpdatedValues(
            pair,
            _lastValue.price0Average,
            _lastValue.price1Average,
            price0Cumulative,
            price1Cumulative,
            blockTimestamp
        );
    }

    function updateAll() public override {
        for (uint8 i = 0; i < pairs.length(); ++i) {
            update(pairs.at(i));
        }
    }
}
