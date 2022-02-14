// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import "../../@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../@openzeppelin/contracts/access/IAccessControlEnumerable.sol";

interface gTRTL is IAccessControlEnumerable, IERC20Permit, IERC20Metadata {
    function MINTER_ROLE() external view returns (bytes32);

    function POLICY_ROLE() external view returns (bytes32);

    function mint(address account, uint256 amount) external;

    function snapshot() external;

    function getCurrentSnapshotId() external view returns (uint256);

    function balanceOfAt(address account, uint256 snapshotId)
        external
        view
        returns (uint256);

    function totalSupplyAt(uint256 snapshotId) external view returns (uint256);
}
