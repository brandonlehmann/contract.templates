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

To save gas when interacting with the contracts, always deploy after compiling with optimizations at `999999`.

