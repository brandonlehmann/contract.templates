// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "../Cloneable/Cloneable.sol";
import "../interfaces/IERC721Snapshot.sol";

contract ERC721Snapshot is IERC721Snapshot, Cloneable, Ownable {
    uint256 public constant VERSION = 2022042301;

    event SnapshotCompleted(uint256 indexed count);

    address[] public holders;
    IERC721Enumerable public CONTRACT;
    uint256 public snapshotPosition;
    uint256 public totalSupply;

    modifier notCompleted() {
        require(!completed(), "Snapshot completed");
        _;
    }

    constructor() {
        _transferOwnership(address(0));
    }

    function completed() public view returns (bool) {
        return snapshotPosition == totalSupply;
    }

    function initialize() public initializer {}

    /**
     * @dev initializes the snapshot from the specified ERC721 contract
     */
    function initialize(IERC721Enumerable ERC721Contract) public initializer {
        CONTRACT = ERC721Contract;
        totalSupply = CONTRACT.totalSupply();
        _transferOwnership(_msgSender());
    }

    /**
     * @dev returns the number of holders found when the snapshot was taken
     */
    function length() public view returns (uint256) {
        return holders.length;
    }

    function snapshot(uint256 maxCount) public notCompleted onlyOwner returns (bool) {
        _snapshot(maxCount);

        if (completed()) {
            emit SnapshotCompleted(holders.length);
            return true;
        }

        return false;
    }

    function _snapshot(uint256 maxCount) internal {
        uint256 count;
        for (snapshotPosition; snapshotPosition < totalSupply; snapshotPosition++) {
            if (++count > maxCount) {
                break;
            }

            holders.push(CONTRACT.ownerOf(CONTRACT.tokenByIndex(snapshotPosition)));
        }
    }
}
