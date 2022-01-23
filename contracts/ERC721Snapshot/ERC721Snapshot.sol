// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "../../@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IERC721Snapshot.sol";

contract ERC721Snapshot is IERC721Snapshot, Initializable {
    address[] public holders;

    /**
     * @dev initializes the snapshot from the specified ERC721 contract
     */
    function initialize(IERC721Enumerable ERC721Contract) public initializer {
        uint256 count = ERC721Contract.totalSupply();
        for (uint256 i = 1; i <= count; ++i) {
            holders.push(ERC721Contract.ownerOf(i));
        }
    }

    /**
     * @dev returns the number of holders found when the snapshot was taken
     */
    function length() public view returns (uint256) {
        return holders.length;
    }
}
