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

| Contract             | Address                                       | Version    | Clonable |
|----------------------|-----------------------------------------------|------------|----------|
| BlockTimeTracker     | `0x06e216fB50E49C9e284dD924cb4278D7B2A714ce`  | 2022021601 | Yes      |
| PaymentSplitter      | `0x718d70C431a9cad76c1029939dE3a40E15197a0f`  | 2022021401 | Yes      |
| RoyaltyManager       | `0x1092C10c4735F813bB0fcFbb11fB34Ed45C42Ff1`  | 2022021401 | Yes      |
| WhitelistManager     | `0x3ce27770098A2413c875980AEA409966D6028660`  | 2022021401 | Yes      |
| ChainlinkRegistry    | `0x49a2BFE2F9aC9Edf4077779E268C9b58F52df1Aa`  | 2022021401 | Yes      |
| ERC721Snapshot       | `0xeAe39b105192ddF1331C6F534875C4ca7Ff7C113`  | 2022021401 | Yes      |
| UniswapV2TWAPOracle  | `0x0E0Ff420EB5D6860DD3eBf3dfE745C335bCA7af7`  | 2022021401 | Yes      |
| ChainlinkPriceOracle | `0x693f31346ecDf2EB1FBf63D0b450Ced6a7f9Cf34`  | 2022021401 | Yes      |
