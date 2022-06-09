// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Based on OpenZeppelin Contracts v4.4.1 (finance/PaymentSplitter.sol)

import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./PaymentSplitterNative.sol";
import "../interfaces/IPaymentSplitterERC20.sol";

abstract contract PaymentSplitterERC20 is PaymentSplitterNative {
    using SafeERC20 for IERC20;

    event ERC20PaymentReleased(address token, address to, uint256 amount);

    mapping(address => uint256) public ERC20TotalReleased;
    mapping(address => mapping(address => uint256)) public ERC20Released;

    /****** PUBLIC METHODS ******/

    function pending(address token, address account) public view returns (uint256) {
        if (shares[account] == 0) {
            return 0;
        }

        uint256 totalReceived = IERC20(token).balanceOf(address(this)) + ERC20TotalReleased[token];

        return _pendingPayment(account, totalReceived, ERC20Released[token][account]);
    }

    function releaseAll(address token) public {
        for (uint256 i = 0; i < payees.length; i++) {
            release(token, payees[i]);
        }
    }

    function release(address token, address account) public {
        if (shares[account] == 0) {
            return;
        }

        uint256 payment = pending(token, account);

        if (payment == 0) {
            return;
        }

        ERC20Released[token][account] += payment;
        ERC20TotalReleased[token] += payment;

        IERC20(token).safeTransfer(account, payment);

        emit ERC20PaymentReleased(token, account, payment);
    }
}
