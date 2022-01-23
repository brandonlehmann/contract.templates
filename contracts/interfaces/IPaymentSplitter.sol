// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPaymentSplitter {
    function initialize(address[] memory payees, uint256[] memory shares_)
        external;

    function count() external view returns (uint256);

    function totalShares() external view returns (uint256);

    function totalReleased() external view returns (uint256);

    function totalReleased(IERC20 token) external view returns (uint256);

    function shares(address account) external view returns (uint256);

    function released(address account) external view returns (uint256);

    function released(IERC20 token, address account)
        external
        view
        returns (uint256);

    function payee(uint256 index) external view returns (address);

    function pending(address account) external view returns (uint256);

    function pending(IERC20 token, address account)
        external
        view
        returns (uint256);

    function release(address payable account) external;

    function release(IERC20 token, address account) external;
}
