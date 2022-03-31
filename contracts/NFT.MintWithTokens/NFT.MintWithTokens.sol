// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../ERC721.Template/ERC721.Template.sol";

contract NFT is ERC721Template {
    using SafeERC20 for IERC20;

    IERC20 public PAYMENT_TOKEN;

    constructor(
        string memory name,
        string memory symbol,
        address _payment_token
    ) ERC721(name, symbol) {
        require(_payment_token != address(0), "PaymentToken cannot be null address");
        PAYMENT_TOKEN = IERC20(_payment_token);
    }

    function mint(uint256 count) public payable override whenNotPaused whenInitialized returns (uint256[] memory) {
        require(count != 0, "ERC20: must mint at least one");
        require(msg.value == 0, "ERC20: caller must not send value");
        require(count <= MAX_TOKENS_PER_MINT, "ERC20: max tokens per mint exceeded");

        uint256 totalMintingFee = MINTING_FEE * count;

        require(
            PAYMENT_TOKEN.allowance(_msgSender(), address(this)) >= totalMintingFee,
            "ERC20: caller did not supply correct amount"
        );

        PAYMENT_TOKEN.safeTransferFrom(_msgSender(), address(this), totalMintingFee);

        uint256[] memory tokenIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _mintNFT(_msgSender());
        }

        return tokenIds;
    }
}
