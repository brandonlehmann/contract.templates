// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Based on OpenZeppelin Contracts v4.4.1 (finance/PaymentSplitter.sol)

import "./PaymentSplitterCore.sol";
import "../interfaces/IPaymentSplitterNative.sol";

abstract contract PaymentSplitterNative is PaymentSplitterCore {
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    uint256 public totalReleased;

    mapping(address => uint256) public released;

    /****** PUBLIC METHODS ******/

    receive() external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
    }

    function pending(address account) public view returns (uint256) {
        if (shares[account] == 0) {
            return 0;
        }

        uint256 totalReceived = address(this).balance + totalReleased;

        return _pendingPayment(account, totalReceived, released[account]);
    }

    function releaseAll() public {
        for (uint256 i = 0; i < payees.length; i++) {
            release(payees[i]);
        }
    }

    function release(address account) public {
        if (shares[account] == 0) {
            return;
        }

        uint256 payment = pending(account);

        if (payment == 0) {
            return;
        }

        released[account] += payment;
        totalReleased += payment;

        (bool sent, ) = account.call{ value: payment }("");

        if (sent) {
            emit PaymentReleased(account, payment);
        }
    }
}
