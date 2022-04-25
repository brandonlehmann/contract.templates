// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/utils/Context.sol";

abstract contract Lockable is Context {
    bool private _locked;

    event Locked(address indexed caller, uint256 blockNumber);
    event Unlocked(address indexed caller, uint256 blockNumber);

    modifier whenNotLocked() {
        require(!_locked, "Contract is locked");
        _;
    }

    modifier whenLocked() {
        require(_locked, "Contract is not locked");
        _;
    }

    function locked() public view returns (bool) {
        return _locked;
    }

    function _lock() internal whenNotLocked {
        _locked = true;
        emit Locked(_msgSender(), block.number);
    }

    function _unlock() internal whenLocked {
        _locked = false;
        emit Unlocked(_msgSender(), block.number);
    }
}
