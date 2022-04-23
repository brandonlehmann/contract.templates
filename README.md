Contains a collection of contract templates I've used in the past to make my life easier.

Most are wrapped around known contract libraries (with updates) such as:

* OpenZeppelin
* UniSwap-v2-core
* UniSwap-v3-core
* Solidity-lib
* Chainlink

Project will flatten each contract so that it's easily deployable via Remix et. al.

To use:

```bash
git clone --recursive https://github.com/brandonlehmann/contract.templates
cd contract.templates
yarn
yarn build
```

Resulting flattened contracts can be found in the resulting `compiled` directory.

To save gas when interacting with the contracts, always deploy after compiling with optimizations at `999999` if possible.

### FTM Deployments

#### Mainnet

| Contract             | Address                                      | Version    | Clonable |
|----------------------|----------------------------------------------|------------|----------|
| BlockTimeTracker     | `0x918DCd379a6669d2eF8bf73919aA07DC58C1393E` | 2022042301 | Yes      |
| ChainlinkPriceOracle | `0x433Ae8Ba731f22377b90b7D0EeF074D2c5589941` | 2022042301 | Yes      |
| ChainlinkRegistry    | `0x177D78a7190481C538d2Eeb0054dAB8f04d3a592` | 2022042301 | Yes      |
| ContractRegistry     | `0xF053aC89d18b3151984fD94368296805A7bDa92F` | 2022042301 | Yes      |
| ERC721Snapshot       | `0x88494Edc824f21C48B3f3319AF6FfAF2146aA08a` | 2022042301 | Yes      |
| PaymentSplitter      | `0x5b9dF37fc3817e88F81F002856092f9B6B7972Ef` | 2022042201 | Yes      |
| RoyaltyManager       | `0x773371327d8E21b67e1bDFb495122563c4cd5F9E` | 2022042301 | Yes      |
| UniswapV2TWAPOracle  | `0xB4C489A742459c6503aBd4C1D4d9231E3F7339bb` | 2022042301 | Yes      |
| WhitelistManager     | `0xF4cDB371Ba073d2ba710CF0959B517Ab5eE2e69F` | 2022042301 | Yes      |
