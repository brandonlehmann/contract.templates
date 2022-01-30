import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Contract } from 'ethers';
import assert from 'assert';

const deploy = async (contract: string, ...args: any[]): Promise<Contract> => {
    const factory = await ethers.getContractFactory(contract);

    return factory.deploy(...args);
};

(async () => {
    let deployer: SignerWithAddress;
    let wallet1: SignerWithAddress;
    let wallet2: SignerWithAddress;
    let ERC721: Contract;
    let PAYMENTSPLITTER: Contract;

    describe('ERC721.SplitRoyalty', async () => {
        before(async () => {
            [deployer, wallet1, wallet2] = await ethers.getSigners();

            PAYMENTSPLITTER = await deploy('PaymentSplitter');

            ERC721 = await deploy('ERC721SplitRoyaltyTemplate', 'TESTNFT', 'TNFT', 0, 1000, 500, PAYMENTSPLITTER.address);
        });

        it('Unpause contract', async () => {
            await ERC721.unpause()
                .catch(() => assert(false));
        });

        it('Mint to wallet1', async () => {
            await ERC721['mintAdmin(address)'](wallet1.address)
                .catch(() => assert(false));
        });

        it('Mint 10 to wallet1', async () => {
            await ERC721['mintAdmin(address,uint256)'](wallet1.address, 10)
                .catch(() => assert(false));
        });

        it('Wallet1 can mint', async () => {
            await (await ERC721.connect(wallet1))['mint()']({ value: 0 })
                .catch(() => assert(false));
        });

        it('Wallet1 cannot mint 10', async () => {
            await (await ERC721.connect(wallet1))['mint(uint256)'](10, { value: 0 })
                .then(() => assert(false))
                .catch(() => assert(true));
        });

        it('Set max mint to 10', async () => {
            await ERC721.setMaxTokensPerMint(10)
                .catch(() => assert(false));
        });

        it('Wallet1 can mint 10', async () => {
            await (await ERC721.connect(wallet1))['mint(uint256)'](10, { value: 0 })
                .catch(() => assert(false));
        });

        it('Wallet1 can transfer token to wallet2', async () => {
            await (await ERC721.connect(wallet1))['safeTransferFrom(address,address,uint256)'](wallet1.address, wallet2.address, 1)
                .catch(() => assert(false));
        });

        it('Get Royalty Receiver', async () => {
            const receiver = await ERC721.royaltyReceiver();

            assert(receiver.length !== 0);
        });

        it('Check Royalty', async () => {
            const receiver = await ERC721.royaltyReceiver();

            const [royaltyReceiver, amount] = await ERC721.royaltyInfo(1, 1_000_000_000)
                .catch(() => assert(false));

            assert(receiver, royaltyReceiver);
            assert(!amount.isZero());
        });

        it('Send some funds to the royalty receiver and distribute them', async () => {
            const receiver = await ERC721.royaltyReceiver();

            await wallet1.sendTransaction({ to: receiver, value: 10_000_000_000 })
                .catch(() => assert(false));

            const deployer_pre_balance = await deployer.getBalance();

            await (await ERC721.connect(wallet2)).payRoyalties()
                .catch(() => assert(false));

            const contract_balance = await ERC721.provider.getBalance(ERC721.address);

            const deployer_balance = await deployer.getBalance();

            assert(!contract_balance.isZero());
            assert(!deployer_balance.isZero());
            assert(deployer_balance.gt(deployer_pre_balance));

            await ERC721['withdraw()']()
                .catch(() => assert(false));
        });

        it('Transfer of tokens triggers royalty distribution', async () => {
            const receiver = await ERC721.royaltyReceiver();

            await wallet1.sendTransaction({ to: receiver, value: 10_000_000_000 })
                .catch(() => assert(false));

            const deployer_pre_balance = await deployer.getBalance();

            await (await ERC721.connect(wallet1))['safeTransferFrom(address,address,uint256)'](wallet1.address, wallet2.address, 2)
                .catch(() => assert(false));

            const contract_balance = await ERC721.provider.getBalance(ERC721.address);

            const deployer_balance = await deployer.getBalance();

            assert(!contract_balance.isZero());
            assert(!deployer_balance.isZero());
            assert(deployer_balance.gt(deployer_pre_balance));

            await ERC721['withdraw()']()
                .catch(() => assert(false));
        });
    });
})();
