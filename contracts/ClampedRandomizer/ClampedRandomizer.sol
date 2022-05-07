// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../libraries/Random.sol";

abstract contract ClampedRandomizer {
    using Random for uint256;

    uint256 private _scopeIndex = 0; //Clamping cache for random TokenID generation in the anti-sniping algo
    uint256 private _scopeCap; //Size of initial randomized number pool & max generated value (zero indexed)
    mapping(uint256 => uint256) private _swappedIDs; //TokenID cache for random TokenID generation in the anti-sniping algo

    constructor(uint256 scopeCap) {
        _scopeCap = scopeCap;
    }

    function _setClampedScope(uint256 scopeCap) internal {
        require(scopeCap >= _scopeCap, "ClampedRandomizer: scopeCap must be >= currentScopeCap");
        _scopeCap = scopeCap;
    }

    function _generateClampedNonce() internal returns (uint256) {
        uint256 scope = _scopeCap - _scopeIndex;
        uint256 swap;
        uint256 result;
        // get random number bound by 2^256-2;
        uint256 i = type(uint256).max.randomize() % scope;
        //Setup the value to swap in for the selected number
        if (_swappedIDs[scope - 1] == 0) {
            swap = scope - 1;
        } else {
            swap = _swappedIDs[scope - 1];
        }
        //Select a random number, swap it out with an unselected one then shorten the selection range by 1
        if (_swappedIDs[i] == 0) {
            result = i;
            _swappedIDs[i] = swap;
        } else {
            result = _swappedIDs[i];
            _swappedIDs[i] = swap;
        }
        _scopeIndex++;
        return result;
    }
}
