// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "../Cloneable/Cloneable.sol";
import "../interfaces/IERC721Snapshot.sol";

contract ERC721Snapshot is IERC721Snapshot, Cloneable, Ownable {
    uint256 public constant VERSION = 2022042501;

    event SnapshotCompleted(address indexed _contract, uint256 indexed count);
    event SnapshotInitialized(address indexed _contract, uint256 indexed totalSupply);
    event SnapshotProgress(uint256 indexed _oldPosition, uint256 indexed _newPosition);

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
        require(ERC721Contract.totalSupply() != 0, "ERC721Enumerable: Contract has no totalSupply");
        CONTRACT = ERC721Contract;
        totalSupply = CONTRACT.totalSupply();
        _transferOwnership(_msgSender());
        emit SnapshotInitialized(address(CONTRACT), totalSupply);
    }

    function clone() public returns (address) {
        return _clone();
    }

    /**
     * @dev returns the number of holders found when the snapshot was taken
     */
    function length() public view returns (uint256) {
        return holders.length;
    }

    /**
     * @dev Progresses through the snapshot up to the maximum number of specified loop iterations
     */
    function snapshot(uint256 maxCount) public notCompleted onlyOwner returns (bool) {
        _snapshot(maxCount);

        if (completed()) {
            emit SnapshotCompleted(address(CONTRACT), holders.length);
            return true;
        }

        return false;
    }

    function _snapshot(uint256 maxCount) internal {
        uint256 old = snapshotPosition;
        uint256 count;
        for (snapshotPosition; snapshotPosition < totalSupply; snapshotPosition++) {
            if (++count > maxCount) {
                break;
            }

            holders.push(CONTRACT.ownerOf(CONTRACT.tokenByIndex(snapshotPosition)));
        }
        emit SnapshotProgress(old, snapshotPosition);
    }
}
