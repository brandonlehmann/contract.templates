// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../abstracts/Cloneable.sol";
import "../PaymentSplitter/PaymentSplitter.sol";
import "../interfaces/IRoyaltyManager.sol";

contract RoyaltyManager is IRoyaltyManager, Cloneable, Ownable {
    event PaymentSplitterDeployed(address indexed _contract);

    uint256 public constant VERSION = 2022042501;

    IPaymentSplitter public immutable PAYMENT_SPLITTER;

    event RoyaltyManagerInitialized(address indexed splitter, address[] indexed accounts, uint256[] indexed shares);
    event RoyaltyDeployed(
        address indexed _contract,
        uint256 indexed _tokenId,
        address indexed account1,
        address account2,
        uint256 shares1,
        uint256 shares2
    );

    IPaymentSplitter public baseRoyaltyReceiver;
    mapping(address => IPaymentSplitter) public knownRoyaltyReceivers;
    mapping(uint256 => address) public tokenRoyaltyReceiver;

    constructor() {
        PAYMENT_SPLITTER = IPaymentSplitter(address(new PaymentSplitter()));
        PAYMENT_SPLITTER.initialize();
        _transferOwnership(address(0));
        emit PaymentSplitterDeployed(address(PAYMENT_SPLITTER));
    }

    function initialize() public initializer {}

    /**
     * @dev Creates an instance of `RoyaltyManager`
     */
    function initialize(address[] memory accounts, uint256[] memory shares) public initializer {
        baseRoyaltyReceiver = IPaymentSplitter(PAYMENT_SPLITTER.clone());
        baseRoyaltyReceiver.initialize(accounts, shares);
        baseRoyaltyReceiver.transferOwnership(_msgSender());
        _transferOwnership(_msgSender());
        emit RoyaltyManagerInitialized(address(baseRoyaltyReceiver), accounts, shares);
    }

    function clone() public returns (address) {
        return _clone();
    }

    /**
     * @dev returns the address of a royalty receiver constructed for the
     * specified account with the number of shares specified
     */
    function add(
        uint256 tokenId,
        uint256 shares1,
        address account2,
        uint256 shares2
    ) public onlyOwner whenInitialized returns (address) {
        if (address(knownRoyaltyReceivers[account2]) == address(0)) {
            knownRoyaltyReceivers[account2] = IPaymentSplitter(PAYMENT_SPLITTER.clone());
            knownRoyaltyReceivers[account2].initialize();
            knownRoyaltyReceivers[account2].addPayee(address(baseRoyaltyReceiver), shares1);
            knownRoyaltyReceivers[account2].addPayee(account2, shares2);
            knownRoyaltyReceivers[account2].transferOwnership(_msgSender());

            emit RoyaltyDeployed(
                address(knownRoyaltyReceivers[account2]),
                tokenId,
                address(baseRoyaltyReceiver),
                account2,
                shares1,
                shares2
            );
        }

        tokenRoyaltyReceiver[tokenId] = account2;

        return address(knownRoyaltyReceivers[account2]);
    }

    /**
     * @dev releases all funds for the specified tokenId contained
     * within the royalty receiver as well as the base royalty receiver
     */
    function releaseAll(uint256 tokenId) public whenInitialized {
        if (tokenRoyaltyReceiver[tokenId] != address(0)) {
            IPaymentSplitter(knownRoyaltyReceivers[tokenRoyaltyReceiver[tokenId]]).releaseAll();
        }

        IPaymentSplitter(baseRoyaltyReceiver).releaseAll();
    }

    /**
     * @dev releases all {token} funds for the specified tokenId contained
     * within the royalty receiver as well as the base royalty receiver
     */
    function releaseAll(uint256 tokenId, address token) public whenInitialized {
        if (tokenRoyaltyReceiver[tokenId] != address(0)) {
            IPaymentSplitter(knownRoyaltyReceivers[tokenRoyaltyReceiver[tokenId]]).releaseAll(token);
        }

        IPaymentSplitter(baseRoyaltyReceiver).releaseAll(token);
    }
}
