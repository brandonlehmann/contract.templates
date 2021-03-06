// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/ICloneable.sol";

interface IPaymentSplitter is ICloneable {
    struct PayeeInformation {
        address account;
        uint256 shares;
    }

    function initialize() external;

    function initialize(address[] memory payees, uint256[] memory shares_) external;

    function addPayee(address payee_, uint256 shares_) external;

    function count() external view returns (uint256);

    function totalShares() external view returns (uint256);

    function totalReleased() external view returns (uint256);

    function totalReleased(address token) external view returns (uint256);

    function shares(address account) external view returns (uint256);

    function released(address account) external view returns (uint256);

    function released(address token, address account) external view returns (uint256);

    function payee(uint256 index) external view returns (address);

    function payees() external view returns (PayeeInformation[] memory);

    function pending(address account) external view returns (uint256);

    function pending(address token, address account) external view returns (uint256);

    function releaseAll() external;

    function releaseAll(address token) external;

    function release(address account) external;

    function release(address token, address account) external;

    function transferOwnership(address newOwner) external;

    function VERSION() external view returns (uint256);
}
