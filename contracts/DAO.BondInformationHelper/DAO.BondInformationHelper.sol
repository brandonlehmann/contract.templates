// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@uniswap-v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../../@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/IBondInformationHelper.sol";

interface IBond {
    function principle() external view returns (address);

    function isLiquidityBond() external view returns (bool);
}

contract BondInformationHelper is IBondInformationHelper {
    /**
     * @dev returns the name(s)) of principle(s) of the bond
     */
    function name(address _bond) public view returns (string memory) {
        address principle = IBond(_bond).principle();

        try IBond(_bond).isLiquidityBond() returns (bool lp) {
            if (!lp) {
                return IERC20Metadata(principle).name();
            } else {
                IUniswapV2Pair pair = IUniswapV2Pair(principle);
                IERC20Metadata token0 = IERC20Metadata(pair.token0());
                IERC20Metadata token1 = IERC20Metadata(pair.token1());

                return string(abi.encodePacked(token0.name(), " / ", token1.name()));
            }
        } catch {
            return IERC20Metadata(principle).name();
        }
    }

    /**
     * @dev returns the symbol(s) of principle(s) of the bond
     */
    function symbol(address _bond) public view returns (string memory) {
        address principle = IBond(_bond).principle();

        try IBond(_bond).isLiquidityBond() returns (bool lp) {
            if (!lp) {
                return IERC20Metadata(principle).symbol();
            } else {
                IUniswapV2Pair pair = IUniswapV2Pair(principle);
                IERC20Metadata token0 = IERC20Metadata(pair.token0());
                IERC20Metadata token1 = IERC20Metadata(pair.token1());

                return string(abi.encodePacked(token0.symbol(), "-", token1.symbol()));
            }
        } catch {
            return IERC20Metadata(principle).symbol();
        }
    }
}
