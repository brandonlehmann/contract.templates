// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "./NonblockingLzApp.sol";
import "./Cloneable.sol";
import "./URIMaskable.sol";
import "./ClampedRandomizer.sol";
import "../interfaces/IERC721.Omnichain.sol";

abstract contract ERC721Omnichain is
    ERC721Enumerable,
    ERC721Pausable,
    ERC721Royalty,
    ERC721Burnable,
    URIMaskable,
    ClampedRandomizer,
    NonblockingLzApp,
    Cloneable,
    IERC721Omnichain
{
    modifier originIsSender() {
        require(tx.origin == _msgSender());
        _;
    }

    /**
     * @dev estimate send token `_tokenId` to (`_dstChainId`, `_toAddress`)
     * _dstChainId - L0 defined chain id to send tokens too
     * _toAddress - dynamic bytes array which contains the address to whom you are sending tokens to on the dstChain
     * _tokenId - token Id to transfer
     * _useZro - indicates to use zro to pay L0 fees
     * _adapterParams - flexible bytes array to indicate messaging adapter services in L0
     */
    function estimateSendFee(
        uint16 dstChainId,
        bytes memory to,
        uint256 tokenId,
        bool useZro,
        bytes memory adapterParams
    ) public view virtual returns (uint256 nativeFee, uint256 zroFee) {
        bytes memory payload = abi.encode(to, tokenId);
        return lzEndpoint.estimateFees(dstChainId, address(this), payload, useZro, adapterParams);
    }

    /**
     * @dev send token `_tokenId` to (`_dstChainId`, `_toAddress`) from `_from`
     * `_toAddress` can be any size depending on the `dstChainId`.
     * `_zroPaymentAddress` set to address(0x0) if not paying in ZRO (LayerZero Token)
     * `_adapterParams` is a flexible bytes array to indicate messaging adapter services
     */
    function sendFrom(
        address from,
        uint16 dstChainId,
        bytes memory to,
        uint256 tokenId,
        address payable refundAddress,
        address zroPaymentAddress,
        bytes memory adapterParams
    ) public payable virtual {
        _send(from, dstChainId, to, tokenId, refundAddress, zroPaymentAddress, adapterParams);
    }

    /****** INTERNAL METHODS ******/

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal virtual override {
        // decode and load the toAddress
        (bytes memory toAddressBytes, uint256 tokenId) = abi.decode(_payload, (bytes, uint256));

        address toAddress;
        assembly {
            toAddress := mload(add(toAddressBytes, 20))
        }

        _creditTo(_srcChainId, toAddress, tokenId);

        emit ReceiveFromChain(_srcChainId, _srcAddress, toAddress, tokenId, _nonce);
    }

    function _creditTo(
        uint16,
        address to,
        uint256 tokenId
    ) internal virtual {
        _safeMint(to, tokenId);
    }

    function _debitFrom(
        address from,
        uint16,
        bytes memory,
        uint256 tokenId
    ) internal virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: send caller is not owner nor approved");
        require(ownerOf(tokenId) == from, "ERC721: send from incorrect owner");

        _burn(tokenId);
    }

    /**
     * @dev send token `_tokenId` to (`_dstChainId`, `_toAddress`) from `_from`
     * `_toAddress` can be any size depending on the `dstChainId`.
     * `_zroPaymentAddress` set to address(0x0) if not paying in ZRO (LayerZero Token)
     * `_adapterParams` is a flexible bytes array to indicate messaging adapter services
     */
    function _send(
        address from,
        uint16 dstChainId,
        bytes memory to,
        uint256 tokenId,
        address payable refundAddress,
        address zroPaymentAddress,
        bytes memory adapterParams
    ) internal virtual {
        _debitFrom(from, dstChainId, to, tokenId);

        bytes memory payload = abi.encode(to, tokenId);

        _lzSend(dstChainId, payload, refundAddress, zroPaymentAddress, adapterParams);

        uint64 nonce = lzEndpoint.getOutboundNonce(dstChainId, address(this));

        emit SendToChain(from, dstChainId, to, tokenId, nonce);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721Royalty) {
        super._burn(tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC721, ERC721Enumerable, ERC721Royalty)
        returns (bool)
    {
        return
            ERC721Enumerable.supportsInterface(interfaceId) ||
            ERC721Royalty.supportsInterface(interfaceId) ||
            ERC721.supportsInterface(interfaceId) ||
            interfaceId == type(IERC721Omnichain).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // default receive function
    receive() external payable virtual {}
}
