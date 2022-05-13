// SPDX-License-Identifier: MIT
// Brandon Lehmann <brandonlehmann@gmail.com>

pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library ERC20Math {
    function toAtomicUnits(address asset, uint256 value) internal view returns (uint256) {
        return value * (10**IERC20Metadata(asset).decimals());
    }

    function fromAtomicUnits(address asset, uint256 value) internal view returns (uint256) {
        return value / (10**IERC20Metadata(asset).decimals());
    }
}
