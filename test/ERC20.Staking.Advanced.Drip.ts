import { ethers } from 'hardhat';
import { Contract, utils, BigNumber } from 'ethers';
import assert from 'assert';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

const increaseTime = async (time = 86400) => {
    await ethers.provider.send('evm_increaseTime', [time]);
    await ethers.provider.send('evm_mine', []);
};

describe('ERC20 Staking Advanced Drip', async () => {
    let deployer: SignerWithAddress;
    let user: SignerWithAddress;
    let user2: SignerWithAddress;
    let ERC20Mock1: Contract;
    let ERC20Mock2: Contract;
    let StakingContract: Contract;
    const InitialBalance = utils.parseEther('1000000.0');

    before(async () => {
        [deployer, user, user2] = await ethers.getSigners();

        {
            const factory = await ethers.getContractFactory('ERC20Mock');
            ERC20Mock1 = await factory.deploy('TEST1', 'TEST1', 18, deployer.address, InitialBalance);
            await ERC20Mock1.deployed();
        }

        {
            const factory = await ethers.getContractFactory('ERC20Mock');
            ERC20Mock2 = await factory.deploy('TEST2', 'TEST2', 18, deployer.address, InitialBalance);
            await ERC20Mock2.deployed();
        }

        {
            const factory = await ethers.getContractFactory('ERC20AdvancedDrip');
            StakingContract = await factory.deploy();
            await StakingContract.deployed();
        }
    });

    describe('ERC20 #1', async () => {
        describe('Deployer', async () => {
            it('approve(address,uint256)', async () => {
                await ERC20Mock1.approve(StakingContract.address, InitialBalance)
                    .catch(() => assert(false));
            });
        });

        describe('User', async () => {
            it('approve(address,uint256)', async () => {
                await (ERC20Mock1.connect(user)).approve(StakingContract.address, InitialBalance)
                    .catch(() => assert(false));
            });
        });
    });

    describe('ERC20 #2', async () => {
        describe('Deployer', async () => {
            it('approve(address,uint256)', async () => {
                await ERC20Mock2.approve(StakingContract.address, InitialBalance)
                    .catch(() => assert(false));
            });
        });

        describe('User', async () => {
            it('approve(address,uint256)', async () => {
                await (ERC20Mock2.connect(user)).approve(StakingContract.address, InitialBalance)
                    .catch(() => assert(false));
            });
        });
    });

    describe('ERC20AdvancedDrip', async () => {
        beforeEach(async () => {
            await increaseTime();
        });

        it('initialize(address)', async () => {
            await StakingContract.initialize(deployer.address)
                .catch(() => assert(false));
        });

        it('setMinimumStakingTime(uint256)', async () => {
            await StakingContract.setMinimumStakingTime(BigNumber.from(86400))
                .catch(() => assert(false));
        });

        it('setRewardWallet(address)', async () => {
            await StakingContract.setRewardWallet(deployer.address)
                .catch(() => assert(false));
        });

        it('configureStakeableAsset(address,address,uint256)', async () => {
            await StakingContract.configureStakeableAsset(
                ERC20Mock1.address,
                ERC20Mock2.address,
                utils.parseEther('1000')
            )
                .catch(() => assert(false));
        });

        it('assets()', async () => {
            const assets: string[] = await StakingContract.assets();

            assert(assets.length === 1);
        });

        it('isPermitted(address)', async () => {
            assert(await StakingContract.isPermitted(ERC20Mock1.address));
        });

        it('rewardRate(address)', async () => {
            const rate: BigNumber = await StakingContract.rewardRate(ERC20Mock1.address);

            assert(rate.isZero());
        });

        it('rewardToken(address)', async () => {
            const token: string = await StakingContract.rewardToken(ERC20Mock1.address);

            assert(token === ERC20Mock2.address);
        });

        it('assetRewards(address)', async () => {
            const reward: {
                dripToken: string,
                dripRate: BigNumber,
                staked: BigNumber
            } = await StakingContract.assetRewards(ERC20Mock1.address);

            assert(reward.staked.isZero());
        });

        it('stake(address,address,uint256,bool) [user]', async () => {
            await StakingContract.stake(
                user.address,
                ERC20Mock1.address,
                utils.parseEther('10'),
                false
            )
                .catch(() => assert(false));
        });

        it('stake(address,address,uint256,bool) [user2]', async () => {
            await StakingContract.stake(
                user2.address,
                ERC20Mock1.address,
                utils.parseEther('20'),
                false
            )
                .catch(() => assert(false));
        });

        it('staked(address) [user]', async () => {
            const stakes: {
                asset: string,
                balance: BigNumber,
                stakedTimestamp: BigNumber,
                lastClaimTimestamp: BigNumber
            }[] = await StakingContract.staked(user.address);

            for (const stake of stakes) {
                assert(!stake.balance.isZero());
            }
        });

        it('staked(address) [user2]', async () => {
            const stakes: {
                asset: string,
                balance: BigNumber,
                stakedTimestamp: BigNumber,
                lastClaimTimestamp: BigNumber
            }[] = await StakingContract.staked(user2.address);

            for (const stake of stakes) {
                assert(!stake.balance.isZero());
            }
        });

        it('assetRewards(address)', async () => {
            const reward: {
                dripToken: string,
                dripRate: BigNumber,
                staked: BigNumber
            } = await StakingContract.assetRewards(ERC20Mock1.address);

            assert(!reward.staked.isZero());
        });

        it('rewardRate(address)', async () => {
            const rate: BigNumber = await StakingContract.rewardRate(ERC20Mock1.address);

            assert(!rate.isZero());
        });

        it('claimable(address,address)', async () => {
            const claim: {
                asset: string,
                reward: string,
                amount: BigNumber
            } = await StakingContract.claimable(user.address, ERC20Mock1.address);

            assert(!claim.amount.isZero());
        });

        it('claimables(address)', async () => {
            const claimables: {
                asset: string,
                reward: string,
                amount: BigNumber
            }[] = await StakingContract.claimables(user.address);

            for (const claimable of claimables) {
                assert(!claimable.amount.isZero());
            }
        });

        it('claim(address,address,bool)', async () => {
            await StakingContract.claim(user.address, ERC20Mock1.address, true)
                .catch(() => assert(false));

            const balance: BigNumber = await ERC20Mock2.balanceOf(user.address);

            assert(!balance.isZero());
        });

        it('claimAll(address,bool)', async () => {
            const startBalance: BigNumber = await ERC20Mock2.balanceOf(user.address);

            await StakingContract.claimAll(user.address, true)
                .catch(() => assert(false));

            const endBalance: BigNumber = await ERC20Mock2.balanceOf(user.address);

            const balance = endBalance.sub(startBalance);

            assert(!balance.isZero());
        });

        it('unstake(address,uint256,bool) [user]', async () => {
            const startBalance1: BigNumber = await ERC20Mock1.balanceOf(user.address);
            const startBalance2: BigNumber = await ERC20Mock2.balanceOf(user.address);

            await (StakingContract.connect(user)).unstake(
                ERC20Mock1.address,
                utils.parseEther('10'),
                true
            )
                .catch(() => assert(false));

            const endBalance1: BigNumber = await ERC20Mock1.balanceOf(user.address);
            const endBalance2: BigNumber = await ERC20Mock2.balanceOf(user.address);

            const balance1 = endBalance1.sub(startBalance1);
            const balance2 = endBalance2.sub(startBalance2);

            console.log(utils.formatEther(balance1), utils.formatEther(balance2));

            assert(!balance1.isZero() && !balance2.isZero());
        });

        it('unstake(address,uint256,bool) [user2]', async () => {
            await increaseTime(86400 * 30);

            const claim: {
                asset: string,
                reward: string,
                amount: BigNumber
            } = await StakingContract.claimable(user2.address, ERC20Mock1.address);

            assert(!claim.amount.isZero());

            const startBalance1: BigNumber = await ERC20Mock1.balanceOf(user2.address);
            const startBalance2: BigNumber = await ERC20Mock2.balanceOf(user2.address);

            await (StakingContract.connect(user2)).unstake(
                ERC20Mock1.address,
                utils.parseEther('20'),
                true
            )
                .catch(() => assert(false));

            const endBalance1: BigNumber = await ERC20Mock1.balanceOf(user2.address);
            const endBalance2: BigNumber = await ERC20Mock2.balanceOf(user2.address);

            const balance1 = endBalance1.sub(startBalance1);
            const balance2 = endBalance2.sub(startBalance2);

            console.log(utils.formatEther(balance1), utils.formatEther(balance2));

            assert(!balance1.isZero() && !balance2.isZero());
        });
    });
});
