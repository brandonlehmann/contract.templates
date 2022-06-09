// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Based on OpenZeppelin Contracts v4.4.1 (finance/PaymentSplitter.sol)

import "../../@openzeppelin/contracts/access/Ownable.sol";
import "./Cloneable.sol";
import "../interfaces/IPaymentSplitterCore.sol";

abstract contract PaymentSplitterCore is Cloneable, Ownable {
    uint256 public constant VERSION = 2022060901;

    event PayeeAdded(address account, uint256 shares);

    uint256 public totalShares;
    mapping(address => uint256) public shares;
    address[] public payees;

    constructor() {
        _transferOwnership(address(0));
    }

    /****** INITIALIZATION METHODS ******/

    function initialize() public initializer {
        _transferOwnership(_msgSender());
    }

    function initialize(address[] memory _payees, uint256[] memory _shares) public initializer {
        require(_payees.length == _shares.length, "PS: payees and shares mismatched length");
        require(_payees.length != 0, "PS: no payees");

        for (uint256 i = 0; i < _payees.length; i++) {
            _addOrUpdatePayee(_payees[i], _shares[i]);
        }

        _transferOwnership(_msgSender());
    }

    /****** PUBLIC METHODS ******/

    function addPayee(address payee_, uint256 shares_) public onlyOwner whenInitialized {
        _addOrUpdatePayee(payee_, shares_);
    }

    function clone() public returns (address) {
        return _clone();
    }

    function count() public view returns (uint256) {
        return payees.length;
    }

    /****** INTERNAL METHODS ******/

    function _addOrUpdatePayee(address _payee, uint256 _shares) internal {
        require(_payee != address(0), "PS: account is null address");
        require(_shares != 0, "PS: shares are 0");

        if (shares[_payee] == 0) {
            payees.push(_payee);
        }

        shares[_payee] += _shares;
        totalShares += _shares;

        emit PayeeAdded(_payee, shares[_payee]);
    }

    function _pendingPayment(
        address account,
        uint256 totalReceived,
        uint256 alreadyReleased
    ) internal view returns (uint256) {
        return (totalReceived * shares[account]) / totalShares - alreadyReleased;
    }
}
