// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// OpenZeppelin Contracts v4.4.1 (finance/PaymentSplitter.sol)

import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Cloneable/Cloneable.sol";
import "../interfaces/IPaymentSplitter.sol";

/**
 * @title PaymentSplitter
 * @dev This contract allows to split Ether payments among a group of accounts. The sender does not need to be aware
 * that the Ether will be split in this way, since it is handled transparently by the contract.
 *
 * The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each
 * account to a number of shares. Of all the Ether that this contract receives, each account will then be able to claim
 * an amount proportional to the percentage of total shares they were assigned.
 *
 * `PaymentSplitter` follows a _pull payment_ model. This means that payments are not automatically forwarded to the
 * accounts but kept in this contract, and the actual transfer is triggered as a separate step by calling the {release}
 * function.
 *
 * NOTE: This contract assumes that ERC20 tokens will behave similarly to native tokens (Ether). Rebasing tokens, and
 * tokens that apply fees during transfers, are likely to not be supported as expected. If in doubt, we encourage you
 * to run tests before sending real value to this contract.
 */
contract PaymentSplitter is IPaymentSplitter, Cloneable, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant VERSION = 2022042201;

    event PayeeAdded(address account, uint256 shares);
    event PaymentReleased(address to, uint256 amount);
    event ERC20PaymentReleased(address indexed token, address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    uint256 private _totalShares;
    uint256 private _totalReleased;

    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    address[] private _payees;

    mapping(address => uint256) private _erc20TotalReleased;
    mapping(address => mapping(address => uint256)) private _erc20Released;

    /**
     * @dev Creates an instance of `PaymentSplitter`
     *
     * Payees must be added via {addPayee} later
     */
    function initialize() public initializer {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Creates an instance of `PaymentSplitter` where each account in `payees` is assigned the number of shares at
     * the matching position in the `shares` array.
     *
     * All addresses in `payees` must be non-zero. Both arrays must have the same non-zero length, and there must be no
     * duplicates in `payees`.
     */
    function initialize(address[] memory payees, uint256[] memory shares_) public initializer {
        require(payees.length == shares_.length, "PaymentSplitter: payees and shares length mismatch");
        require(payees.length > 0, "PaymentSplitter: no payees");

        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares_[i]);
        }

        _transferOwnership(_msgSender());
    }

    /**
     * @dev Adds another payee to the `PaymentSplitter` with the specified number of `shares`
     * for the `payee`
     *
     * `payee` must be non-zero and the payee must not already exist
     */
    function addPayee(address payee_, uint256 shares_) public onlyOwner whenInitialized {
        _addPayee(payee_, shares_);
    }

    /**
     * @dev The Ether received will be logged with {PaymentReceived} events. Note that these events are not fully
     * reliable: it's possible for a contract to receive Ether without triggering this function. This only affects the
     * reliability of the events, and not the actual splitting of Ether.
     *
     * To learn more about this see the Solidity documentation for
     * https://solidity.readthedocs.io/en/latest/contracts.html#fallback-function[fallback
     * functions].
     */
    receive() external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
    }

    function count() public view returns (uint256) {
        return _payees.length;
    }

    /**
     * @dev Getter for the total shares held by payees.
     */
    function totalShares() public view returns (uint256) {
        return _totalShares;
    }

    /**
     * @dev Getter for the total amount of Ether already released.
     */
    function totalReleased() public view returns (uint256) {
        return _totalReleased;
    }

    /**
     * @dev Getter for the total amount of `token` already released. `token` should be the address of an IERC20
     * contract.
     */
    function totalReleased(address token) public view returns (uint256) {
        return _erc20TotalReleased[token];
    }

    /**
     * @dev Getter for the amount of shares held by an account.
     */
    function shares(address account) public view returns (uint256) {
        return _shares[account];
    }

    /**
     * @dev Getter for the amount of Ether already released to a payee.
     */
    function released(address account) public view returns (uint256) {
        return _released[account];
    }

    /**
     * @dev Getter for the amount of `token` tokens already released to a payee. `token` should be the address of an
     * IERC20 contract.
     */
    function released(address token, address account) public view returns (uint256) {
        return _erc20Released[token][account];
    }

    /**
     * @dev Getter for the address of the payee number `index`.
     */
    function payee(uint256 index) public view returns (address) {
        return _payees[index];
    }

    function pending(address account) public view returns (uint256) {
        if (_shares[account] == 0) {
            return 0;
        }

        uint256 totalReceived = address(this).balance + totalReleased();

        return _pendingPayment(account, totalReceived, released(account));
    }

    function pending(address token, address account) public view returns (uint256) {
        if (_shares[account] == 0) {
            return 0;
        }

        uint256 totalReceived = IERC20(token).balanceOf(address(this)) + totalReleased(token);

        return _pendingPayment(account, totalReceived, released(token, account));
    }

    function releaseAll() public virtual {
        for (uint8 i = 0; i < _payees.length; i++) {
            release(_payees[i]);
        }
    }

    function releaseAll(address token) public virtual {
        for (uint8 i = 0; i < _payees.length; i++) {
            release(token, _payees[i]);
        }
    }

    /**
     * @dev Triggers a transfer to `account` of the amount of Ether they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */
    function release(address account) public virtual {
        if (_shares[account] == 0) {
            return;
        }

        uint256 payment = pending(account);

        if (payment == 0) {
            return;
        }

        _released[account] += payment;
        _totalReleased += payment;

        (bool sent, ) = account.call{ value: payment }("");

        if (sent) {
            emit PaymentReleased(account, payment);
        }
    }

    /**
     * @dev Triggers a transfer to `account` of the amount of `token` tokens they are owed, according to their
     * percentage of the total shares and their previous withdrawals. `token` must be the address of an IERC20
     * contract.
     */
    function release(address token, address account) public virtual {
        if (_shares[account] == 0) {
            return;
        }

        uint256 payment = pending(token, account);

        if (payment == 0) {
            return;
        }

        _erc20Released[token][account] += payment;
        _erc20TotalReleased[token] += payment;

        IERC20(token).safeTransfer(account, payment);

        emit ERC20PaymentReleased(token, account, payment);
    }

    /**
     * @dev internal logic for computing the pending payment of an `account` given the token historical balances and
     * already released amounts.
     */
    function _pendingPayment(
        address account,
        uint256 totalReceived,
        uint256 alreadyReleased
    ) private view returns (uint256) {
        return (totalReceived * _shares[account]) / _totalShares - alreadyReleased;
    }

    /**
     * @dev Add a new payee to the contract.
     * @param account The address of the payee to add.
     * @param shares_ The number of shares owned by the payee.
     */
    function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        require(_shares[account] == 0, "PaymentSplitter: account already has shares");

        _payees.push(account);
        _shares[account] = shares_;
        _totalShares = _totalShares + shares_;
        emit PayeeAdded(account, shares_);
    }

    function transferOwnership(address newOwner) public override(IPaymentSplitter, Ownable) onlyOwner {
        super._transferOwnership(newOwner);
    }
}
