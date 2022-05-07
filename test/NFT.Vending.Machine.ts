import { ethers } from 'hardhat';
import { Contract, ContractTransaction, utils } from 'ethers';
import assert from 'assert';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

describe('NFT Vending Machine', async () => {
    let deployer: SignerWithAddress;
    let ERC721Mock1: Contract;
    let ERC721Mock2: Contract;
    let ERC1155Mock: Contract;
    let VendingMachine: Contract;
    let VendingMachineClone: Contract;

    before(async () => {
        [deployer] = await ethers.getSigners();

        {
            const factory = await ethers.getContractFactory('ERC721Mock');
            ERC721Mock1 = await factory.deploy('TEST 1', 'TEST1');
            await ERC721Mock1.deployed();
        }

        {
            const factory = await ethers.getContractFactory('ERC721Mock');
            ERC721Mock2 = await factory.deploy('TEST 2', 'TEST2');
            await ERC721Mock2.deployed();
        }

        {
            const factory = await ethers.getContractFactory('ERC1155SupplyMock');
            ERC1155Mock = await factory.deploy('TESTBIG');
            await ERC1155Mock.deployed();
        }

        {
            const factory = await ethers.getContractFactory('NFTVendingMachine');
            VendingMachine = await factory.deploy();
            await VendingMachine.deployed();
        }
    });

    describe('ERC721 #1', async () => {
        it('Mint 1', async () => {
            await ERC721Mock1.mint();
            await ERC721Mock1.mint();
            await ERC721Mock1.mint();
            await ERC721Mock1.mint();
            await ERC721Mock1.mint();

            assert(!(await ERC721Mock1.balanceOf(deployer.address)).isZero());
        });
    });

    describe('ERC721 #2', async () => {
        it('Mint 1', async () => {
            await ERC721Mock2.mint();

            assert(!(await ERC721Mock2.balanceOf(deployer.address)).isZero());
        });
    });

    describe('ERC1155', async () => {
        it('Mint 1', async () => {
            await ERC1155Mock.mint(deployer.address, 1, 1, '0x00');

            assert(!(await ERC1155Mock.balanceOf(deployer.address, 1)).isZero());
        });
    });

    describe('NFT VendingMachine', async () => {
        before(async () => {
            const tx: ContractTransaction = await VendingMachine.clone();
            const receipt = await tx.wait();
            const address = '0x' + receipt.logs
                .filter(elem => elem.topics[0] === '0xd64439e08c1b01a555bbbbb0ae43010ec863b6280c9dae54ad824a77a99422e0')
                .map(elem => elem.topics[3])[0]
                .slice(-40);
            VendingMachineClone = new Contract(address, VendingMachine.interface, deployer);
        });

        it('isClone()', async () => {
            assert(await VendingMachineClone.isClone());
        });

        it('Initialize', async () => {
            await VendingMachineClone.initialize();

            assert((await VendingMachineClone.owner()) === deployer.address);
        });

        it('unpause fails', async () => {
            VendingMachineClone.unpause()
                .then(() => assert(false))
                .catch(() => assert(true));
        });

        describe('ERC721Mock1 - 1.0 FTM', async () => {
            it('depositTokens fails', async () => {
                VendingMachineClone.depositTokens(ERC721Mock1.address, [1])
                    .then(() => assert(false))
                    .catch(() => assert(true));
            });

            it('enableCollection', async () => {
                await VendingMachineClone.enableCollection(ERC721Mock1.address, 0, utils.parseEther('1.0'), deployer.address);
            });

            it('depositTokens fails', async () => {
                VendingMachineClone.depositTokens(ERC721Mock1.address, [1])
                    .then(() => assert(false))
                    .catch(() => assert(true));
            });

            it('setApprovalForAll', async () => {
                await ERC721Mock1.setApprovalForAll(VendingMachineClone.address, true);
            });

            it('depositTokens', async () => {
                await VendingMachineClone.depositTokens(ERC721Mock1.address, [1]);
            });

            it('depositTokens (multiple)', async () => {
                await VendingMachineClone.depositTokens(ERC721Mock1.address, [2, 3, 4]);
            });

            after(async () => {
                console.log('Collection Count: %s', (await VendingMachineClone.collectionsCount()).toNumber());
                console.log('Draw Price: %s', utils.formatEther(await VendingMachineClone.drawPrice()));
                console.log('Prize Count: %s', (await VendingMachineClone.prizeCount()).toNumber());
            });
        });

        describe('ERC721Mock2 - 10.0 FTM', async () => {
            it('depositTokens fails', async () => {
                VendingMachineClone.depositTokens(ERC721Mock2.address, [1])
                    .then(() => assert(false))
                    .catch(() => assert(true));
            });

            it('enableCollection', async () => {
                await VendingMachineClone.enableCollection(ERC721Mock2.address, 0, utils.parseEther('10.0'), deployer.address);
            });

            it('depositTokens fails', async () => {
                VendingMachineClone.depositTokens(ERC721Mock2.address, [1])
                    .then(() => assert(false))
                    .catch(() => assert(true));
            });

            it('setApprovalForAll', async () => {
                await ERC721Mock2.setApprovalForAll(VendingMachineClone.address, true);
            });

            it('depositTokens', async () => {
                await VendingMachineClone.depositTokens(ERC721Mock2.address, [1]);
            });

            after(async () => {
                console.log('Collection Count: %s', (await VendingMachineClone.collectionsCount()).toNumber());
                console.log('Draw Price: %s', utils.formatEther(await VendingMachineClone.drawPrice()));
                console.log('Prize Count: %s', (await VendingMachineClone.prizeCount()).toNumber());
            });
        });

        describe('ERC1155Mock - 20.0 FTM', async () => {
            it('depositTokens fails', async () => {
                VendingMachineClone.depositTokens(ERC1155Mock.address, [1])
                    .then(() => assert(false))
                    .catch(() => assert(true));
            });

            it('enableCollection', async () => {
                await VendingMachineClone.enableCollection(ERC1155Mock.address, 1, utils.parseEther('20.0'), deployer.address);
            });

            it('depositTokens fails', async () => {
                VendingMachineClone.depositTokens(ERC1155Mock.address, [1])
                    .then(() => assert(false))
                    .catch(() => assert(true));
            });

            it('setApprovalForAll', async () => {
                await ERC1155Mock.setApprovalForAll(VendingMachineClone.address, true);
            });

            it('depositTokens', async () => {
                await VendingMachineClone.depositTokens(ERC1155Mock.address, [1]);
            });

            after(async () => {
                console.log('Collection Count: %s', (await VendingMachineClone.collectionsCount()).toNumber());
                console.log('Draw Price: %s', utils.formatEther(await VendingMachineClone.drawPrice()));
                console.log('Prize Count: %s', (await VendingMachineClone.prizeCount()).toNumber());
            });
        });

        describe('Test Draws', async () => {
            it('unpause', async () => {
                await VendingMachineClone.unpause();
            });

            it('Ownership renounced', async () => {
                assert((await VendingMachineClone.owner()) !== deployer.address);
            });

            it('depositTokens fails', async () => {
                VendingMachineClone.depositTokens(ERC721Mock2.address, 1)
                    .then(() => assert(false))
                    .catch(() => assert(true));
            });

            it('depositTokens fails', async () => {
                VendingMachineClone.depositTokens(ERC1155Mock.address, 1)
                    .then(() => assert(false))
                    .catch(() => assert(true));
            });

            describe('Drawing', async () => {
                for (let i = 0; i < 6; i++) {
                    it('draw', async () => {
                        await VendingMachineClone.draw({ value: await VendingMachineClone.drawPrice() });
                    });
                }

                it('draw fails', async () => {
                    VendingMachineClone.draw({ value: await VendingMachineClone.drawPrice() })
                        .then(() => assert(false))
                        .catch(() => assert(true));
                });

                afterEach(async () => {
                    console.log('Collection Count: %s', (await VendingMachineClone.collectionsCount()).toNumber());
                    console.log('Draw Price: %s', utils.formatEther(await VendingMachineClone.drawPrice()));
                    console.log('Prize Count: %s', (await VendingMachineClone.prizeCount()).toNumber());
                });
            });
        });
    });
});
