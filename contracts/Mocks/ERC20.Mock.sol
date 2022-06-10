// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../abstracts/ERC20.Omnichain.sol";

contract ERC20Mock is ERC20Omnichain {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address initialAccount,
        uint256 initialBalance
    ) payable ERC20(name, symbol, decimals) ERC20Permit(name) LzApp(address(0)) {
        _mint(initialAccount, initialBalance);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function transferInternal(
        address from,
        address to,
        uint256 value
    ) public {
        _transfer(from, to, value);
    }

    function approveInternal(
        address owner,
        address spender,
        uint256 value
    ) public {
        _approve(owner, spender, value);
    }
}
