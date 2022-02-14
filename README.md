Contains a collection of contract templates I've used in the past to make my life easier.

Most are wrapped around known contract libraries (with updates) such as:

* OpenZeppelin
* UniSwap-v2-core
* UniSwap-v3-core
* Solidity-lib

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

| Contract          | Address                                        | Version    | Clonable |
|-------------------|------------------------------------------------|------------|----------|
| BlockTimeTracker  | `0xE3812438c87DdcaFA0796244851E3e01ec1C848c`   | 2022021401 | No       |
| PaymentSplitter   | `0x339af1762dDFd44BfEa062576c5f2D4B91C21475`   | 2022021401 | Yes      |
| RoyaltyManager    | `0xd9a1F4b944f215E74E0751Ae9EE86e49C4c2e623`   | 2022021401 | Yes      |
| WhitelistManager  | `0xA90a6555cc5F1d2c5EeD30258ae10978D837d5d5`   | 2022021401 | Yes      |
| ChainlinkRegistry | `0xC821f5a79c182D3BFc7dD40B5825349ff2915cd8`   |            | No       |
| ERC721Snapshot    | `0xeAe39b105192ddF1331C6F534875C4ca7Ff7C113`   | 2022021401 | Yes      |
