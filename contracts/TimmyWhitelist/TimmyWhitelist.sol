// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "../../@openzeppelin/contracts/utils/Context.sol";
import "../../@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/ITimmyNFT.sol";

contract TimmyWhitelist is Context {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => uint256) public whitelist;
    ITimmyNFT public Timmy;
    address public TRADING_PAIR;
    IERC20 public PAYMENT_TOKEN;
    IUniswapV2TWAPOracle public ORACLE;
    EnumerableSet.AddressSet private whitelistMembers;

    modifier onlyTimmyAdmin() {
        require(
            Timmy.hasRole(Timmy.DEFAULT_ADMIN_ROLE(), _msgSender()),
            "not a timmy admin"
        );
        _;
    }

    modifier onlyTimmyPauser() {
        require(
            Timmy.hasRole(Timmy.PAUSER_ROLE(), _msgSender()),
            "not a timmy pauser"
        );
        _;
    }

    modifier whenTimmyUnPausedOrWhitelisted() {
        require(
            !Timmy.paused() || whitelistMembers.contains(_msgSender()),
            "minting is currently paused"
        );
        _;
    }

    constructor() {
        Timmy = ITimmyNFT(0x82a0aC751c118c7D4DEe71fBb7436862D339e550);
        TRADING_PAIR = Timmy.TRADING_PAIR();
        ORACLE = Timmy.ORACLE();
        PAYMENT_TOKEN = Timmy.PAYMENT_TOKEN();
    }

    function addToWhitelist(address wallet) public onlyTimmyAdmin {
        require(
            !whitelistMembers.contains(wallet),
            "Wallet already in whitelist"
        );
        whitelistMembers.add(wallet);
    }

    function removeFromWhitelist(address wallet) public onlyTimmyAdmin {
        require(
            whitelistMembers.contains(wallet),
            "Wallet is not in the whitelist"
        );
        whitelistMembers.remove(wallet);
    }

    function DEFAULT_ADMIN_ROLE() public view returns (bytes32) {
        return Timmy.DEFAULT_ADMIN_ROLE();
    }

    function PAUSER_ROLE() public view returns (bytes32) {
        return Timmy.PAUSER_ROLE();
    }

    function MINTING_FEE() public view returns (uint256) {
        return Timmy.MINTING_FEE();
    }

    function MAX_TOKENS_PER_MINT() public view returns (uint256) {
        return Timmy.MAX_TOKENS_PER_MINT();
    }

    function FTM_PREMIUM() public view returns (uint256) {
        return Timmy.FTM_PREMIUM();
    }

    function MAX_SUPPLY() public view returns (uint256) {
        return Timmy.MAX_SUPPLY();
    }

    function getFTMQuote() public view returns (uint256) {
        return Timmy.getFTMQuote();
    }

    function getFTMQuoteSlippage()
        internal
        view
        returns (uint256 _min, uint256 _max)
    {
        uint256 mintFee = getFTMQuote();
        _min = (mintFee * 9750) / 10000; // allows for -2.5%
        _max = (mintFee * 10250) / 10000; // allows for +2.5%
    }

    function updateOracle() internal {
        ORACLE.update(TRADING_PAIR);
    }

    function mint()
        public
        payable
        whenTimmyUnPausedOrWhitelisted
        returns (uint256)
    {
        (uint256 min, uint256 max) = getFTMQuoteSlippage();
        require(
            msg.value >= min && msg.value <= max,
            "ERC20: caller did not supply correct amount of FTM"
        );

        if (Timmy.paused()) {
            require(
                whitelist[_msgSender()] + 1 <= MAX_TOKENS_PER_MINT(),
                "whitelist allotment exceeded"
            );

            whitelist[_msgSender()] += 1;
        }

        // forward the funds to Timmy
        payable(address(Timmy)).transfer(msg.value);

        updateOracle();

        return Timmy.mintAdmin(_msgSender());
    }

    function mintCount(uint8 count)
        public
        payable
        whenTimmyUnPausedOrWhitelisted
        returns (uint256[] memory)
    {
        require(
            count <= MAX_TOKENS_PER_MINT(),
            "ERC721: must mint less than the maximum count per mint"
        );

        (uint256 min, uint256 max) = getFTMQuoteSlippage();

        require(
            msg.value >= min * count && msg.value <= max * count,
            "ERC20: caller did not supply correct amount of FTM"
        );

        if (Timmy.paused()) {
            require(
                whitelist[_msgSender()] + count <= MAX_TOKENS_PER_MINT(),
                "whitelist allotment exceeded"
            );

            whitelist[_msgSender()] += count;
        }

        // forward the funds to Timmy
        payable(address(Timmy)).transfer(msg.value);

        updateOracle();

        return Timmy.mintAdminCount(_msgSender(), count);
    }

    function mintWithToken()
        public
        whenTimmyUnPausedOrWhitelisted
        returns (uint256)
    {
        require(
            PAYMENT_TOKEN.allowance(_msgSender(), address(this)) >=
                MINTING_FEE(),
            "ERC20: caller must provide approval to spend token"
        );

        if (Timmy.paused()) {
            require(
                whitelist[_msgSender()] + 1 <= MAX_TOKENS_PER_MINT(),
                "whitelist allotment exceeded"
            );

            whitelist[_msgSender()] += 1;
        }

        PAYMENT_TOKEN.safeTransferFrom(
            _msgSender(),
            address(this),
            MINTING_FEE()
        );

        PAYMENT_TOKEN.safeTransfer(address(Timmy), MINTING_FEE());

        return Timmy.mintAdmin(_msgSender());
    }

    function mintWithTokenCount(uint256 count)
        public
        whenTimmyUnPausedOrWhitelisted
        returns (uint256[] memory)
    {
        require(
            count <= MAX_TOKENS_PER_MINT(),
            "ERC721: must mint less than the maximum count per mint"
        );

        uint256 totalMintingFee = MINTING_FEE() * count;

        require(
            PAYMENT_TOKEN.allowance(_msgSender(), address(this)) >=
                totalMintingFee,
            "ERC20: caller must provide approval to spend token"
        );

        if (Timmy.paused()) {
            require(
                whitelist[_msgSender()] + count <= MAX_TOKENS_PER_MINT(),
                "whitelist allotment exceeded"
            );

            whitelist[_msgSender()] += count;
        }

        PAYMENT_TOKEN.safeTransferFrom(
            _msgSender(),
            address(this),
            totalMintingFee
        );

        PAYMENT_TOKEN.safeTransfer(address(Timmy), totalMintingFee);

        return Timmy.mintAdminCount(_msgSender(), count);
    }

    function mintAdmin(address _to) public onlyTimmyAdmin returns (uint256) {
        return Timmy.mintAdmin(_to);
    }

    function mintAdminCount(address _to, uint256 count)
        public
        onlyTimmyAdmin
        returns (uint256[] memory)
    {
        return Timmy.mintAdminCount(_to, count);
    }

    function paused() public view returns (bool) {
        bool _paused = Timmy.paused();

        if (_paused && whitelistMembers.contains(_msgSender())) {
            return !(_paused);
        } else {
            return _paused;
        }
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        return IERC721Metadata(address(Timmy)).tokenURI(tokenId);
    }

    function totalSupply() public view returns (uint256) {
        return Timmy.totalSupply();
    }

    function pause() public onlyTimmyPauser {
        Timmy.pause();
    }

    function unpause() public onlyTimmyPauser {
        Timmy.unpause();
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return Timmy.hasRole(role, account);
    }

    function withdraw() public onlyTimmyAdmin {
        Timmy.withdraw();
        payable(address(this)).transfer(address(this).balance);
    }

    function withdraw(IERC20 token) public onlyTimmyAdmin {
        Timmy.withdraw(token);
        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    }

    function balanceOf(address owner) public view returns (uint256) {
        return Timmy.balanceOf(owner);
    }

    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        returns (uint256)
    {
        return Timmy.tokenOfOwnerByIndex(owner, index);
    }

    receive() external payable {}
}
