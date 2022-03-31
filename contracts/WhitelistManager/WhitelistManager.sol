// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/security/Pausable.sol";
import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../../@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IWhitelistManager.sol";

contract WhitelistManager is IWhitelistManager, Initializable, Ownable, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant VERSION = 2022021401;

    event AccountAdded(address indexed account, uint256 indexed count);
    event AccountRemoved(address indexed account);

    EnumerableSet.AddressSet private _entries;
    mapping(address => uint256) private _counts;

    /**
     * @dev initializes a the WhitelistManager after cloning
     */
    function initialize() public initializer {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev adds an account to the whitelist with the specified count
     */
    function add(address account, uint256 _count) public onlyOwner whenInitialized returns (bool) {
        require(!_entries.contains(account), "WHITELIST: entry already exists");
        _counts[account] = _count;
        bool result = _entries.add(account);
        if (result) {
            emit AccountAdded(account, _count);
        }
        return result;
    }

    /**
     * @dev checks to return if the specified account is in the whitelist as well
     * as returns the remaining count for the account
     */
    function check(address account) public view returns (bool _exists, uint256 _count) {
        _exists = _entries.contains(account);
        _count = _counts[account];
    }

    /**
     * @dev returns if the specified account is listed in the whitelist
     */
    function contains(address account) public view returns (bool) {
        return _entries.contains(account);
    }

    /**
     * @dev returns the total count of accounts in the whitelist
     */
    function count() public view returns (uint256) {
        return _entries.length();
    }

    /**
     * @dev decrements the remaining count for the specified account
     */
    function decrement(address account) public onlyOwner whenInitialized {
        require(_counts[account] > 0, "WHITELIST: not enough count remaining to satisfy request");
        _counts[account] -= 1;
    }

    /**
     * @dev decrements the remaining count by the {_count} for the specified account
     */
    function decrement(address account, uint256 _count) public onlyOwner whenInitialized {
        require(_counts[account] >= _count, "WHITELIST: not enough count remaining to satisfy request");
        _counts[account] -= _count;
    }

    /**
     * @dev returns the current whitelist entry for the specified account
     */
    function entry(address account) public view returns (address _account, uint256 _count) {
        _account = account;
        _count = _counts[account];
    }

    /**
     * @dev returns the current whitelist entry at the specified index
     */
    function entry(uint256 index) public view returns (address _account, uint256 _count) {
        _account = _entries.at(index);
        _count = _counts[_account];
    }

    /**
     * @dev pauses the whitelist
     */
    function pause() public onlyOwner whenInitialized {
        _pause();
    }

    /**
     * @dev returns if the whitelist is currently paused
     */
    function paused() public view override(IWhitelistManager, Pausable) returns (bool) {
        return super.paused();
    }

    /**
     * @dev returns the remaining count for the specified account
     */
    function remaining(address account) public view returns (uint256) {
        return _counts[account];
    }

    /**
     * @dev removes the specified account from the whitelist
     */
    function remove(address account) public onlyOwner whenInitialized returns (bool) {
        require(_entries.contains(account), "WHITELIST: entry does not exist");
        bool result = _entries.remove(account);
        if (result) {
            emit AccountRemoved(account);
        }
        return result;
    }

    /**
     * @dev unpauses the whitelist
     */
    function unpause() public onlyOwner whenInitialized {
        _unpause();
    }

    /**
     * @dev returns all of the accounts in the whitelist
     */
    function values() public view returns (address[] memory) {
        return _entries.values();
    }
}
