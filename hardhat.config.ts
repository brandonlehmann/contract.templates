import { HardhatUserConfig } from 'hardhat/config';
import '@nomiclabs/hardhat-ethers';
import '@openzeppelin/hardhat-upgrades';
import { config as dotenv } from 'dotenv';
import '@nomiclabs/hardhat-waffle';
import { resolve } from 'path';

dotenv();

export const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.10',
        settings: {
            optimizer: {
                enabled: true,
                runs: 4294967295
            }
        }
    },
    paths: {
        sources: resolve(process.cwd() + '/contracts'),
        root: resolve(process.cwd())
    },
    defaultNetwork: 'hardhat'
};

export default config;
