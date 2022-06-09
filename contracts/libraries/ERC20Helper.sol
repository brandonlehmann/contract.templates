// SPDX-License-Identifier: MIT
// Brandon Lehmann <brandonlehmann@gmail.com>

pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library ERC20Helper {
    function decimals(address token) internal view returns (uint8) {
        return _decimals(token);
    }

    function decimals(IERC20 token) internal view returns (uint8) {
        return _decimals(address(token));
    }

    function name(address token) internal view returns (string memory) {
        return _name(token);
    }

    function name(IERC20 token) internal view returns (string memory) {
        return _name(address(token));
    }

    function symbol(address token) internal view returns (string memory) {
        return _symbol(token);
    }

    function symbol(IERC20 token) internal view returns (string memory) {
        return _symbol(address(token));
    }

    function toWei(address token, uint256 value) internal view returns (uint256) {
        return value * (10**_decimals(token));
    }

    function toWei(IERC20 token, uint256 value) internal view returns (uint256) {
        return value * (10**_decimals(address(token)));
    }

    function weiToWholeUnits(address token, uint256 value) internal view returns (uint256) {
        return value / (10**_decimals(token));
    }

    function weiToWholeUnits(IERC20 token, uint256 value) internal view returns (uint256) {
        return value / (10**_decimals(address(token)));
    }

    /****** PRIVATE METHODS ******/

    function _decimals(address token) private view returns (uint8) {
        return IERC20Metadata(token).decimals();
    }

    function _name(address token) private view returns (string memory) {
        return IERC20Metadata(token).name();
    }

    function _symbol(address token) private view returns (string memory) {
        return IERC20Metadata(token).symbol();
    }
}
