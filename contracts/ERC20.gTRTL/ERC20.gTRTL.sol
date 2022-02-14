// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "../../@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "../../@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract gTRTL is ERC20Snapshot, ERC20Permit, AccessControlEnumerable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant POLICY_ROLE = keccak256("POLICY_ROLE");

    constructor()
        ERC20("Governance TurtleCoin", "gTRTL", 18)
        ERC20Permit("gTRTL")
    {
        _setupRole(
            DEFAULT_ADMIN_ROLE,
            address(0x7E6CaC527cc907f70dA4Ef514DA285046e75ba28)
        );
        _setupRole(
            POLICY_ROLE,
            address(0x7E6CaC527cc907f70dA4Ef514DA285046e75ba28)
        );

        // only policy can can define minters
        _setRoleAdmin(MINTER_ROLE, POLICY_ROLE);
    }

    function mint(address account, uint256 amount)
        public
        onlyRole(MINTER_ROLE)
    {
        _mint(account, amount);
    }

    function snapshot() public onlyRole(POLICY_ROLE) {
        _snapshot();
    }

    function getCurrentSnapshotId() public view returns (uint256) {
        return _getCurrentSnapshotId();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
