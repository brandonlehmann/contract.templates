// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IPaymentSplitterCore.sol";

interface IPaymentSplitterNative is IPaymentSplitterCore {
    function pending(address payee) external view returns (uint256);

    function release(address payee) external;

    function releaseAll() external;

    function released(address payee) external view returns (uint256);

    function totalReleased() external view returns (uint256);
}
