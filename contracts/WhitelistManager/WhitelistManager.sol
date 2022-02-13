// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/security/Pausable.sol";
import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../../@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IWhitelistManager.sol";

contract WhitelistManager is
    IWhitelistManager,
    Initializable,
    Ownable,
    Pausable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    event AccountAdded(address indexed account, uint256 indexed count);
    event AccountRemoved(address indexed account);

    EnumerableSet.AddressSet private _entries;
    mapping(address => uint256) private _counts;

    function initialize() public initializer {
        _transferOwnership(_msgSender());
    }

    function add(address account, uint256 _count)
        public
        onlyOwner
        returns (bool)
    {
        require(!_entries.contains(account), "WHITELIST: entry already exists");
        _counts[account] = _count;
        bool result = _entries.add(account);
        if (result) {
            emit AccountAdded(account, _count);
        }
        return result;
    }

    function check(address account)
        public
        view
        returns (bool _exists, uint256 _count)
    {
        _exists = _entries.contains(account);
        _count = _counts[account];
    }

    function contains(address account) public view returns (bool) {
        return _entries.contains(account);
    }

    function count() public view returns (uint256) {
        return _entries.length();
    }

    function decrement(address account) public onlyOwner {
        require(
            _counts[account] > 0,
            "WHITELIST: not enough count remaining to satisfy request"
        );
        _counts[account] -= 1;
    }

    function decrement(address account, uint256 _count) public onlyOwner {
        require(
            _counts[account] >= _count,
            "WHITELIST: not enough count remaining to satisfy request"
        );
        _counts[account] -= _count;
    }

    function entry(address account)
        public
        view
        returns (address _account, uint256 _count)
    {
        _account = account;
        _count = _counts[account];
    }

    function entry(uint256 index)
        public
        view
        returns (address _account, uint256 _count)
    {
        _account = _entries.at(index);
        _count = _counts[_account];
    }

    function pause() public onlyOwner {
        _pause();
    }

    function paused()
        public
        view
        override(IWhitelistManager, Pausable)
        returns (bool)
    {
        return super.paused();
    }

    function remaining(address account) public view returns (uint256) {
        return _counts[account];
    }

    function remove(address account) public onlyOwner returns (bool) {
        require(_entries.contains(account), "WHITELIST: entry does not exist");
        bool result = _entries.remove(account);
        if (result) {
            emit AccountRemoved(account);
        }
        return result;
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function values() public view returns (address[] memory) {
        return _entries.values();
    }
}
