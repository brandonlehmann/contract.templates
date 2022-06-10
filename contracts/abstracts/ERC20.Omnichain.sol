// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../../@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "../../@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./NonblockingLzApp.sol";
import "./Cloneable.sol";
import "../interfaces/IERC20.Omnichain.sol";

abstract contract ERC20Omnichain is
    ERC20Permit,
    ERC20Pausable,
    ERC20Burnable,
    NonblockingLzApp,
    Cloneable,
    IERC20Omnichain
{
    /**
     * @dev estimate send token `_tokenId` to (`_dstChainId`, `_toAddress`)
     * _dstChainId - L0 defined chain id to send tokens too
     * _toAddress - dynamic bytes array which contains the address to whom you are sending tokens to on the dstChain
     * _amount - amount of token to transfer
     * _useZro - indicates to use zro to pay L0 fees
     * _adapterParams - flexible bytes array to indicate messaging adapter services in L0
     */
    function estimateSendFee(
        uint16 dstChainId,
        bytes memory to,
        uint256 amount,
        bool useZro,
        bytes memory adapterParams
    ) public view virtual returns (uint256 nativeFee, uint256 zroFee) {
        bytes memory payload = abi.encode(to, amount);
        return lzEndpoint.estimateFees(dstChainId, address(this), payload, useZro, adapterParams);
    }

    /**
     * @dev send `_amount` of token to (`_dstChainId`, `_toAddress`) from `_from`
     * `_toAddress` can be any size depending on the `dstChainId`.
     * `_zroPaymentAddress` set to address(0x0) if not paying in ZRO (LayerZero Token)
     * `_adapterParams` is a flexible bytes array to indicate messaging adapter services
     */
    function sendFrom(
        address from,
        uint16 dstChainId,
        bytes memory to,
        uint256 amount,
        address payable refundAddress,
        address zroPaymentAddress,
        bytes memory adapterParams
    ) public payable virtual {
        _send(from, dstChainId, to, amount, refundAddress, zroPaymentAddress, adapterParams);
    }

    /****** INTERNAL METHODS ******/

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal virtual override {
        // decode and load the toAddress
        (bytes memory toAddressBytes, uint256 amount) = abi.decode(_payload, (bytes, uint256));

        address toAddress;
        assembly {
            toAddress := mload(add(toAddressBytes, 20))
        }

        _creditTo(_srcChainId, toAddress, amount);

        emit ReceiveFromChain(_srcChainId, _srcAddress, toAddress, amount, _nonce);
    }

    function _creditTo(
        uint16,
        address to,
        uint256 amount
    ) internal virtual {
        _mint(to, amount);
    }

    function _debitFrom(
        address from,
        uint16,
        bytes memory,
        uint256 amount
    ) internal virtual {
        if (_msgSender() != from) {
            _spendAllowance(from, _msgSender(), amount);
        }
        _burn(from, amount);
    }

    /**
     * @dev send `_amount` of token to (`_dstChainId`, `_toAddress`) from `_from`
     * `_toAddress` can be any size depending on the `dstChainId`.
     * `_zroPaymentAddress` set to address(0x0) if not paying in ZRO (LayerZero Token)
     * `_adapterParams` is a flexible bytes array to indicate messaging adapter services
     */
    function _send(
        address from,
        uint16 dstChainId,
        bytes memory to,
        uint256 amount,
        address payable refundAddress,
        address zroPaymentAddress,
        bytes memory adapterParams
    ) internal virtual {
        _debitFrom(from, dstChainId, to, amount);

        bytes memory payload = abi.encode(to, amount);

        _lzSend(dstChainId, payload, refundAddress, zroPaymentAddress, adapterParams);

        uint64 nonce = lzEndpoint.getOutboundNonce(dstChainId, address(this));

        emit SendToChain(from, dstChainId, to, amount, nonce);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC20Omnichain).interfaceId;
    }
}
