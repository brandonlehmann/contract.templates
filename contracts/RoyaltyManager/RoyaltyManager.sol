// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../@openzeppelin/contracts/proxy/Clones.sol";
import "../PaymentSplitter/PaymentSplitter.sol";
import "../interfaces/IRoyaltyManager.sol";

contract RoyaltyManager is IRoyaltyManager, Initializable, Ownable {
    using Clones for address;

    uint256 public constant VERSION = 2022021401;

    event RoyaltyDeployed(
        address indexed _contract,
        uint256 indexed _tokenId,
        address indexed account1,
        address account2,
        uint256 shares1,
        uint256 shares2
    );

    address public baseRoyaltyReceiver;
    mapping(address => address) public knownRoyaltyReceivers;
    mapping(uint256 => address) public tokenRoyaltyReceiver;

    /**
     * @dev Creates an instance of `RoyaltyManager`
     */
    function initialize(
        address account1,
        uint256 shares1,
        address account2,
        uint256 shares2
    ) public initializer {
        baseRoyaltyReceiver = address(new PaymentSplitter());
        IPaymentSplitter(baseRoyaltyReceiver).initialize();
        IPaymentSplitter(baseRoyaltyReceiver).addPayee(account1, shares1);
        IPaymentSplitter(baseRoyaltyReceiver).addPayee(account2, shares2);

        emit RoyaltyDeployed(
            baseRoyaltyReceiver,
            0,
            account1,
            account2,
            shares1,
            shares2
        );

        _transferOwnership(_msgSender());
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
        if (knownRoyaltyReceivers[account2] == address(0)) {
            knownRoyaltyReceivers[account2] = baseRoyaltyReceiver.clone();
            IPaymentSplitter(knownRoyaltyReceivers[account2]).initialize();
            IPaymentSplitter(knownRoyaltyReceivers[account2]).addPayee(
                baseRoyaltyReceiver,
                shares1
            );
            IPaymentSplitter(knownRoyaltyReceivers[account2]).addPayee(
                account2,
                shares2
            );

            emit RoyaltyDeployed(
                knownRoyaltyReceivers[account2],
                tokenId,
                baseRoyaltyReceiver,
                account2,
                shares1,
                shares2
            );
        }

        tokenRoyaltyReceiver[tokenId] = account2;

        return knownRoyaltyReceivers[account2];
    }

    /**
     * @dev helper method that returns a clone of a {PaymentSplitter} that
     * is initialized and the ownership transferred to the caller
     */
    function cloneSplitter() public whenInitialized returns (address) {
        address result = baseRoyaltyReceiver.clone();

        IPaymentSplitter(result).initialize();
        IPaymentSplitter(result).transferOwnership(_msgSender());

        return result;
    }

    /**
     * @dev releases all funds for the specified tokenId contained
     * within the royalty receiver as well as the base royalty receiver
     */
    function releaseAll(uint256 tokenId) public whenInitialized {
        if (tokenRoyaltyReceiver[tokenId] != address(0)) {
            IPaymentSplitter(
                knownRoyaltyReceivers[tokenRoyaltyReceiver[tokenId]]
            ).releaseAll();
        }

        IPaymentSplitter(baseRoyaltyReceiver).releaseAll();
    }

    /**
     * @dev releases all {token} funds for the specified tokenId contained
     * within the royalty receiver as well as the base royalty receiver
     */
    function releaseAll(uint256 tokenId, address token) public whenInitialized {
        if (tokenRoyaltyReceiver[tokenId] != address(0)) {
            IPaymentSplitter(
                knownRoyaltyReceivers[tokenRoyaltyReceiver[tokenId]]
            ).releaseAll(token);
        }

        IPaymentSplitter(baseRoyaltyReceiver).releaseAll(token);
    }
}
