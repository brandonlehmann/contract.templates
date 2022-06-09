// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IPaymentSplitterNative.sol";

interface IPaymentSplitterERC20 is IPaymentSplitterNative {
    function ERC20Released(address token, address payee) external view returns (uint256);

    function ERC20TotalReleased(address payee) external view returns (uint256);

    function pending(address token, address payee) external view returns (uint256);

    function release(address token, address payee) external;

    function releaseAll(address token) external;
}
