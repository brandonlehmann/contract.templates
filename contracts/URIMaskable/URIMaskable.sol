// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/utils/Strings.sol";
import "../../@openzeppelin/contracts/utils/Context.sol";
import "../libraries/Random.sol";

abstract contract URIMaskable is Context {
    using Strings for uint256;
    using Random for uint256;

    event ChangeURIService(address indexed _old, address indexed _new);
    event URIMasked();
    event URIUnmasked();

    uint256 private _RANDOM_SEED;
    bool private _URI_MASKED;
    address private _URI_SERVICE;

    modifier whenURINotMasked() {
        require(!_URI_MASKED, "URI masked");
        _;
    }

    modifier whenURIMasked() {
        require(_URI_MASKED, "URI not masked");
        _;
    }

    modifier onlyMaskService() {
        require(_msgSender() == _URI_SERVICE, "Not masking service");
        _;
    }

    /****** PUBLIC METHODS ******/

    function URI_MASKED() public view returns (bool) {
        return _URI_MASKED;
    }

    /****** INTERNAL METHODS ******/

    function _disableMasking() internal whenURIMasked {
        _URI_MASKED = false;
        emit URIUnmasked();
    }

    function _enableMasking() internal whenURINotMasked {
        _RANDOM_SEED = type(uint256).max.randomize();
        _URI_MASKED = true;
        emit URIMasked();
    }

    function _generateURIMask(uint256 tokenId) internal view returns (string memory) {
        return uint256(keccak256(abi.encodePacked(_RANDOM_SEED, tokenId))).toHexString(32);
    }

    function _setMaskingService(address service) internal {
        address old = _URI_SERVICE;
        _URI_SERVICE = service;
        emit ChangeURIService(old, service);
    }
}
