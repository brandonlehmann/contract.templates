// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "../../@openzeppelin/contracts/access/IAccessControlEnumerable.sol";
import "../interfaces/IUniswapV2TWAPOracle.sol";

interface ITimmyNFT is IERC721Enumerable, IAccessControlEnumerable {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function PAUSER_ROLE() external view returns (bytes32);

    function MINTING_FEE() external view returns (uint256);

    function MAX_TOKENS_PER_MINT() external view returns (uint256);

    function FTM_PREMIUM() external view returns (uint256);

    function TRADING_PAIR() external view returns (address);

    function PAYMENT_TOKEN() external view returns (IERC20);

    function ORACLE() external view returns (IUniswapV2TWAPOracle);

    function MAX_SUPPLY() external view returns (uint256);

    function getFTMQuote() external view returns (uint256);

    function mintAdmin(address _to) external returns (uint256);

    function paused() external view returns (bool);

    function mintAdminCount(address _to, uint256 count)
        external
        returns (uint256[] memory);

    function pause() external;

    function unpause() external;

    function withdraw() external;

    function withdraw(IERC20 token) external;
}
