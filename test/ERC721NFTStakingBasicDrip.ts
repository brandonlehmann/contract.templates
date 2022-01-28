import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Contract, BigNumber } from 'ethers';
import assert from 'assert';

const maxSupply = BigNumber.from(5_000_000).mul(BigNumber.from(10).pow(18));
const singleSupply = BigNumber.from(1).mul(BigNumber.from(10).pow(18));
const nullAddress = '0x0000000000000000000000000000000000000000';

const deploy = async (contract: string, ...args: any[]): Promise<Contract> => {
    const factory = await ethers.getContractFactory(contract);

    return factory.deploy(...args);
};

const mineBlock = async () => {
    await ethers.provider.send('evm_mine', []);
};

const increaseTime = async (value: number) => {
    await ethers.provider.send('evm_increaseTime', [value]);
};

const advanceTime = async (days: number) => {
    await increaseTime(60 * 60 * 24 * days);

    return mineBlock();
};

(async () => {
    let wallet1: SignerWithAddress;
    let wallet2: SignerWithAddress;
    let ERC20: Contract;
    let ERC721: Contract;
    let ERC721NFTStakingBasicDrip: Contract;
    let lastClaim = BigNumber.from(0);

    describe('ERC721NFTStakingBasicDrip Tests [third-party reward wallet]', async () => {
        before(async () => {
            [, wallet1, wallet2] = await ethers.getSigners();

            ERC20 = await deploy('ERC20Mock', 'TESTERC20', 'TESTERC20', 18, wallet1.address, maxSupply);

            ERC721 = await deploy('ERC721Template', 'TESTNFT', 'TESTNFT', 0, 10, 0);

            ERC721NFTStakingBasicDrip = await deploy('ERC721NFTStakingBasicDrip', wallet1.address);
        });

        it('Approve ERC721NFTStakingBasicDrip for Wallet1 ERC20 balance', async () => {
            await ERC20.connect(wallet1)
                .approve(ERC721NFTStakingBasicDrip.address, maxSupply)
                .catch(() => assert(false));
        });

        it('Unpause ERC721', async () => {
            await ERC721.unpause()
                .catch(() => assert(false));
        });

        it('Wallet2 mint ERC721', async () => {
            await ERC721.connect(wallet2)['mint()']()
                .catch(() => assert(false));
        });

        it('Wallet2 owns token ID #1', async () => {
            const owner = await ERC721.ownerOf(1);

            assert(owner === wallet2.address);
        });

        it('Wallet2 cannot stake yet', async () => {
            await ERC721NFTStakingBasicDrip.connect(wallet2)
                .stake(ERC721.address, 1, ERC20.address)
                .then(() => assert(false))
                .catch(() => assert(true));
        });

        it('Permit ERC20 as reward token for 1 Token per day', async () => {
            await ERC721NFTStakingBasicDrip.permitRewardToken(ERC20.address, singleSupply)
                .catch(() => assert(false));
        });

        it('Check Runway Status', async () => {
            const runway = await ERC721NFTStakingBasicDrip.runway(ERC20.address)
                .catch(() => assert(false));

            assert(runway._runRatePerSecond.isZero());
        });

        it('Wallet2 cannot stake yet', async () => {
            await ERC721NFTStakingBasicDrip.connect(wallet2)
                .stake(ERC721.address, 1, ERC20.address)
                .then(() => assert(false))
                .catch(() => assert(true));
        });

        it('Permit ERC721 as NFT', async () => {
            await ERC721NFTStakingBasicDrip.permitNFT(ERC721.address)
                .catch(() => assert(false));
        });

        it('Wallet2 cannot stake yet', async () => {
            await ERC721NFTStakingBasicDrip.connect(wallet2)
                .stake(ERC721.address, 1, ERC20.address)
                .then(() => assert(false))
                .catch(() => assert(true));
        });

        it('Wallet2 approve contract for ERC721', async () => {
            await ERC721.connect(wallet2)
                .approve(ERC721NFTStakingBasicDrip.address, 1)
                .catch(() => assert(false));
        });

        it('Wallet2 does not have staked NFTs', async () => {
            const nfts = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .staked(wallet2.address)
                .catch(() => assert(false));

            assert(nfts.length === 0);
        });

        it('Wallet2 can stake', async () => {
            await ERC721NFTStakingBasicDrip.connect(wallet2)
                .stake(ERC721.address, 1, ERC20.address)
                .catch((e: any) => {
                    console.log(e.toString());
                    assert(false);
                });
        });

        it('Wallet2 has staked NFTs', async () => {
            const nfts = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .staked(wallet2.address)
                .catch(() => assert(false));

            assert(nfts.length !== 0);
        });

        it('Check Runway Status', async () => {
            const runway = await ERC721NFTStakingBasicDrip.runway(ERC20.address)
                .catch(() => assert(false));

            assert(!runway._runRatePerSecond.isZero());
        });

        it('Wallet2 has stake ids', async () => {
            const ids = await ERC721NFTStakingBasicDrip.stakeIds(wallet2.address)
                .catch(() => assert(false));

            assert(ids.length !== 0);
        });

        it('Wallet2 Claimable should be 0', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            const claim = status[0].amount;

            assert(claim.isZero());

            lastClaim = claim;
        });

        it('Advance time by 12 hours', async () => {
            await advanceTime(0.5)
                .catch(() => assert(false));
        });

        it('Wallet2 Claimable should be 0', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            const claim = status[0].amount;

            assert(claim.isZero());

            lastClaim = claim;
        });

        it('Advance time by a day', async () => {
            await advanceTime(1)
                .catch(() => assert(false));
        });

        it('Wallet2 should have claimable balance', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            const claim = status[0].amount;

            assert(claim.gt(lastClaim));

            lastClaim = claim;
        });

        it('Wallet2 can single claim by stake id', async () => {
            const ids = await ERC721NFTStakingBasicDrip.stakeIds(wallet2.address)
                .catch(() => assert(false));

            await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claim(ids[0])
                .catch(() => assert(false));
        });

        it('Advance time by a day', async () => {
            await advanceTime(1)
                .catch(() => assert(false));
        });

        it('Wallet2 claimable balance should be less than the last', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            const claim = status[0].amount;

            assert(claim.lt(lastClaim));

            lastClaim = claim;
        });

        it('Wallet2 can claim all', async () => {
            await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimAll(wallet2.address)
                .catch(() => assert(false));

            const balance = await ERC20.balanceOf(wallet2.address);

            assert(!balance.isZero());
        });

        it('Wallet2 Claimable should be 0', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            const claim = status[0].amount;

            assert(claim.isZero());

            lastClaim = claim;
        });

        it('Advance time by a day', async () => {
            await advanceTime(1)
                .catch(() => assert(false));
        });

        it('Wallet2 claimable balance should increase', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            const claim = status[0].amount;

            assert(claim.gt(lastClaim));

            lastClaim = claim;
        });

        it('Wallet2 should be able to unstake', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            await ERC721NFTStakingBasicDrip.connect(wallet2)
                .unstake(status[0].stakeId)
                .catch(() => assert(false));

            await ERC721.ownerOf(1)
                .then((owner: string) => assert(owner === wallet2.address));
        });

        it('Wallet2 should have no remaining stakes', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            assert(status.length === 0);
        });

        it('Check Wallet2 total rewards', async () => {
            const [, rewards] = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .rewardHistory(wallet2.address);

            assert(!rewards[0].isZero());
        });

        it('Wallet2 does not have staked NFTs', async () => {
            const nfts = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .staked(wallet2.address)
                .catch(() => assert(false));

            assert(nfts.length === 0);
        });

        it('Wallet2 has stake ids', async () => {
            const ids = await ERC721NFTStakingBasicDrip.stakeIds(wallet2.address)
                .catch(() => assert(false));

            assert(ids.length === 0);
        });

        it('Check Runway Status', async () => {
            const runway = await ERC721NFTStakingBasicDrip.runway(ERC20.address)
                .catch(() => assert(false));

            assert(runway._runRatePerSecond.isZero());
        });
    });

    describe('ERC721NFTStakingBasicDrip Tests [contract holds rewards]', async () => {
        before(async () => {
            [, wallet1, wallet2] = await ethers.getSigners();

            ERC721NFTStakingBasicDrip = await deploy('ERC721NFTStakingBasicDrip', nullAddress);

            ERC20 = await deploy('ERC20Mock', 'TESTERC20', 'TESTERC20', 18, ERC721NFTStakingBasicDrip.address, maxSupply);

            ERC721 = await deploy('ERC721Template', 'TESTNFT', 'TESTNFT', 0, 10, 0);
        });

        it('Unpause ERC721', async () => {
            await ERC721.unpause()
                .catch(() => assert(false));
        });

        it('Wallet2 mint ERC721', async () => {
            await ERC721.connect(wallet2)['mint()']()
                .catch(() => assert(false));
        });

        it('Wallet2 owns token ID #1', async () => {
            const owner = await ERC721.ownerOf(1);

            assert(owner === wallet2.address);
        });

        it('Wallet2 cannot stake yet', async () => {
            await ERC721NFTStakingBasicDrip.connect(wallet2)
                .stake(ERC721.address, 1, ERC20.address)
                .then(() => assert(false))
                .catch(() => assert(true));
        });

        it('Permit ERC20 as reward token for 1 Token per day', async () => {
            await ERC721NFTStakingBasicDrip.permitRewardToken(ERC20.address, singleSupply)
                .catch(() => assert(false));
        });

        it('Check Runway Status', async () => {
            const runway = await ERC721NFTStakingBasicDrip.runway(ERC20.address)
                .catch(() => assert(false));

            assert(runway._runRatePerSecond.isZero());
        });

        it('Wallet2 cannot stake yet', async () => {
            await ERC721NFTStakingBasicDrip.connect(wallet2)
                .stake(ERC721.address, 1, ERC20.address)
                .then(() => assert(false))
                .catch(() => assert(true));
        });

        it('Permit ERC721 as NFT', async () => {
            await ERC721NFTStakingBasicDrip.permitNFT(ERC721.address)
                .catch(() => assert(false));
        });

        it('Wallet2 cannot stake yet', async () => {
            await ERC721NFTStakingBasicDrip.connect(wallet2)
                .stake(ERC721.address, 1, ERC20.address)
                .then(() => assert(false))
                .catch(() => assert(true));
        });

        it('Wallet2 approve contract for ERC721', async () => {
            await ERC721.connect(wallet2)
                .approve(ERC721NFTStakingBasicDrip.address, 1)
                .catch(() => assert(false));
        });

        it('Wallet2 does not have staked NFTs', async () => {
            const nfts = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .staked(wallet2.address)
                .catch(() => assert(false));

            assert(nfts.length === 0);
        });

        it('Wallet2 can stake', async () => {
            await ERC721NFTStakingBasicDrip.connect(wallet2)
                .stake(ERC721.address, 1, ERC20.address)
                .catch((e: any) => {
                    console.log(e.toString());
                    assert(false);
                });
        });

        it('Wallet2 has staked NFTs', async () => {
            const nfts = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .staked(wallet2.address)
                .catch(() => assert(false));

            assert(nfts.length !== 0);
        });

        it('Check Runway Status', async () => {
            const runway = await ERC721NFTStakingBasicDrip.runway(ERC20.address)
                .catch(() => assert(false));

            assert(!runway._runRatePerSecond.isZero());
        });

        it('Wallet2 has stake ids', async () => {
            const ids = await ERC721NFTStakingBasicDrip.stakeIds(wallet2.address)
                .catch(() => assert(false));

            assert(ids.length !== 0);
        });

        it('Wallet2 Claimable should be 0', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            const claim = status[0].amount;

            assert(claim.isZero());

            lastClaim = claim;
        });

        it('Advance time by 12 hours', async () => {
            await advanceTime(0.5)
                .catch(() => assert(false));
        });

        it('Wallet2 Claimable should be 0', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            const claim = status[0].amount;

            assert(claim.isZero());

            lastClaim = claim;
        });

        it('Advance time by a day', async () => {
            await advanceTime(1)
                .catch(() => assert(false));
        });

        it('Wallet2 should have claimable balance', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            const claim = status[0].amount;

            assert(claim.gt(lastClaim));

            lastClaim = claim;
        });

        it('Wallet2 can single claim by stake id', async () => {
            const ids = await ERC721NFTStakingBasicDrip.stakeIds(wallet2.address)
                .catch(() => assert(false));

            await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claim(ids[0])
                .catch(() => assert(false));
        });

        it('Advance time by a day', async () => {
            await advanceTime(1)
                .catch(() => assert(false));
        });

        it('Wallet2 claimable balance should be less than the last', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            const claim = status[0].amount;

            assert(claim.lt(lastClaim));

            lastClaim = claim;
        });

        it('Wallet2 can claim all', async () => {
            await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimAll(wallet2.address)
                .catch(() => assert(false));

            const balance = await ERC20.balanceOf(wallet2.address);

            assert(!balance.isZero());
        });

        it('Wallet2 Claimable should be 0', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            const claim = status[0].amount;

            assert(claim.isZero());

            lastClaim = claim;
        });

        it('Advance time by a day', async () => {
            await advanceTime(1)
                .catch(() => assert(false));
        });

        it('Wallet2 claimable balance should increase', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            const claim = status[0].amount;

            assert(claim.gt(lastClaim));

            lastClaim = claim;
        });

        it('Wallet2 should be able to unstake', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            await ERC721NFTStakingBasicDrip.connect(wallet2)
                .unstake(status[0].stakeId)
                .catch(() => assert(false));

            await ERC721.ownerOf(1)
                .then((owner: string) => assert(owner === wallet2.address));
        });

        it('Wallet2 should have no remaining stakes', async () => {
            const status = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .claimable(wallet2.address);

            assert(status.length === 0);
        });

        it('Check Wallet2 total rewards', async () => {
            const [, rewards] = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .rewardHistory(wallet2.address);

            assert(!rewards[0].isZero());
        });

        it('Wallet2 does not have staked NFTs', async () => {
            const nfts = await ERC721NFTStakingBasicDrip.connect(wallet2)
                .staked(wallet2.address)
                .catch(() => assert(false));

            assert(nfts.length === 0);
        });

        it('Wallet2 has stake ids', async () => {
            const ids = await ERC721NFTStakingBasicDrip.stakeIds(wallet2.address)
                .catch(() => assert(false));

            assert(ids.length === 0);
        });

        it('Check Runway Status', async () => {
            const runway = await ERC721NFTStakingBasicDrip.runway(ERC20.address)
                .catch(() => assert(false));

            assert(runway._runRatePerSecond.isZero());
        });
    });
})();
