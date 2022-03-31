// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IWalletAggregator.sol";

contract WalletAggregator is IWalletAggregator, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    event AddWallet(address indexed _wallet);
    event RemoveWallet(address indexed _wallet);

    EnumerableSet.AddressSet _wallets;

    /****** OPERATIONAL METHODS ******/

    /**
     * @dev adds the specified wallet to the wallet aggregator set
     */
    function add(address _wallet) public onlyOwner {
        require(!_wallets.contains(_wallet), "wallet address already added");
        _wallets.add(_wallet);
        emit AddWallet(_wallet);
    }

    /**
     * @dev retrieves the total balance of all wallets under management for the given token
     */
    function balanceOf(address _token) public view returns (uint256) {
        uint256 balance = 0;
        for (uint256 i = 0; i < _wallets.length(); i++) {
            balance += _balanceOf(_token, _wallets.at(i));
        }
        return balance;
    }

    /**
     * @dev removes the specified wallet from the wallet aggregator set
     */
    function remove(address _wallet) public onlyOwner {
        require(_wallets.contains(_wallet), "wallet address does not exist");
        _wallets.remove(_wallet);
        emit RemoveWallet(_wallet);
    }

    /**
     * @dev transfers the full balance of the specified token from all of the wallets
     * in the wallet aggregator set for which they have a balance AND the contract has
     * an allowance
     */
    function transfer(address _token) public returns (uint256) {
        uint256 total = 0;

        // loop through all of the wallets in the aggregator set
        for (uint256 i = 0; i < _wallets.length(); i++) {
            // get their balances of the token
            uint256 balance = _balanceOf(_token, _wallets.at(i));

            // if the balance is 0, skip to the next
            if (balance == 0) {
                continue;
            }

            // get the allowance specified for this contract for the given wallet in the aggregator set
            uint256 allowance = _allowanceOf(_token, _wallets.at(i));

            // if we have permission to send more than the balance in the wallet, do so
            if (allowance >= balance) {
                // bring the tokens to the contract
                IERC20(_token).safeTransferFrom(_wallets.at(i), address(this), balance);

                total += balance;
            }
        }

        require(total > 0, "nothing to transfer");

        // send the aggregated tokens to the owner of the contract
        IERC20(_token).safeTransfer(owner(), total);

        return total;
    }

    /**
     * @dev sends the full balance of the contract to the owner of the contract
     */
    function withdraw() public {
        require(address(this).balance != 0, "contract has no balance");
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev sends the full balance of the contract for the specified token to the owner of the contract
     */
    function withdraw(address _token) public {
        require(IERC20(_token).balanceOf(address(this)) != 0, "contract has no balance of token");
        IERC20(_token).safeTransfer(owner(), IERC20(_token).balanceOf(address(this)));
    }

    receive() external payable {}

    /****** INTERNAL HELPER METHODS ******/

    function _allowanceOf(address _token, address _wallet) internal view returns (uint256) {
        return IERC20(_token).allowance(_wallet, address(this));
    }

    function _balanceOf(address _token, address _wallet) internal view returns (uint256) {
        return IERC20(_token).balanceOf(_wallet);
    }
}
