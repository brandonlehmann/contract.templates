// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../../@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../../@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../../@openzeppelin/contracts/access/Ownable.sol";

contract ERC721NFTStakingBasicDrip is IERC721Receiver, Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    event Stake(address indexed owner, address indexed nftContract, uint256 indexed tokenId, address rewardToken);
    event UnStake(address indexed owner, address indexed nftContract, uint256 indexed tokenId, address rewardToken);
    event RewardWalletChanged(address indexed oldRewardWallet, address indexed newRewardWallet);
    event MinimumStakingTimeChanged(uint256 indexed oldTime, uint256 newTime);
    event PermittedRewardToken(address indexed token, uint256 dripRate);
    event ChangeDripRate(address indexed token, uint256 oldDripRate, uint256 newDripRate);
    event DeniedRewardToken(address indexed token, uint256 dripRate);
    event PermittedNFTContract(address indexed nftContract);
    event DeniedNFTContract(address indexed nftContract);
    event ClaimRewards(bytes32 indexed stakeId, address indexed owner, uint256 indexed amount);
    event ReceivedERC721(address operator, address from, uint256 tokenId, bytes data, uint256 gas);

    // holds the list of permitted NFTs
    EnumerableSet.AddressSet private permittedNFTs;

    // holds the list of currently permitted reward tokens
    EnumerableSet.AddressSet private permittedRewardTokens;

    // holds the list of all permitted reward tokens (active or not)
    EnumerableSet.AddressSet private allRewardTokens;

    // holds the reward token drip rate
    mapping(address => uint256) public rewardTokenDripRate;

    struct StakedNFT {
        bytes32 stakeId; // the stake id of the stake
        address owner; // the owner of the NFT
        IERC721 nftContract; // the ERC721 contract for which the NFT belongs
        uint256 tokenId; // the token ID staked
        uint256 stakedTimestamp; // the time that the NFT was staked
        uint256 lastClaimTimestamp; // the last time that the user claimed rewards for this NFT
        IERC20 rewardToken; // the token to reward for staking
    }

    struct ClaimableInfo {
        bytes32 stakeId; // the stake id
        address rewardToken; // the token to reward for staking
        uint256 amount; // the amount of the reward for the stake id
    }

    // holds the mapping of stake ids to the staked NFT values
    mapping(bytes32 => StakedNFT) public stakedNFTs;

    // holds the mapping of stakers to their staking ids
    mapping(address => EnumerableSet.Bytes32Set) private userStakes;

    // holds the mapping of the staker's reward payments
    mapping(address => mapping(address => uint256)) private userRewards;

    // holds the number of staked NFTs per reward token
    mapping(address => uint256) public stakesPerRewardToken;

    // holds the amount of rewards paid by reward token for all users
    mapping(address => uint256) public rewardsPaid;

    // holds the address of the wallet that contains the staking rewards
    address public rewardWallet;

    // the minimum amount of time required before claiming rewards via the drip
    uint256 public MINIMUM_STAKING_TIME_FOR_REWARDS;

    constructor(address _rewardWallet) {
        // if we specify a null address for the reward wallet, then we'll use ourself
        rewardWallet = (_rewardWallet != address(0)) ? _rewardWallet : address(this);

        MINIMUM_STAKING_TIME_FOR_REWARDS = 24 hours;

        emit RewardWalletChanged(address(0), _rewardWallet);
        emit MinimumStakingTimeChanged(0, MINIMUM_STAKING_TIME_FOR_REWARDS);
    }

    /****** STANDARD OPERATIONS ******/

    /**
     * @dev returns information regarding how long the current rewards for the token
     * in the reward wallet can maintain the current drip rate
     */
    function runway(IERC20 token)
        public
        view
        returns (
            uint256 _balance,
            uint256 _dripRatePerSecond,
            uint256 _stakeCount,
            uint256 _runRatePerSecond,
            uint256 _runRatePerDay,
            uint256 _runwaySeconds,
            uint256 _runwayDays
        )
    {
        _balance = token.balanceOf(rewardWallet);

        _stakeCount = stakesPerRewardToken[address(token)];

        _dripRatePerSecond = rewardTokenDripRate[address(token)];

        _runRatePerSecond = _dripRatePerSecond * _stakeCount;

        _runRatePerDay = _runRatePerSecond * 24 hours;

        if (_runRatePerSecond != 0) {
            _runwaySeconds = _balance / _runRatePerSecond;
        } else {
            _runwaySeconds = type(uint256).max;
        }

        _runwayDays = _runwaySeconds / 24 hours;
    }

    /**
     * @dev returns an array of all staked NFT for the specified account
     */
    function staked(address account) public view returns (StakedNFT[] memory) {
        // retrieve all of the stake ids for the caller
        bytes32[] memory ids = stakeIds(account);

        // construct the temporary staked information
        StakedNFT[] memory stakes = new StakedNFT[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
            stakes[i] = stakedNFTs[ids[i]];
        }

        return stakes;
    }

    /**
     * @dev returns a paired set of arrays that gives the history of
     * all rewards paid to account regardless of if the contract
     * currently permits the reward token
     */
    function rewardHistory(address account)
        public
        view
        returns (address[] memory _rewardTokens, uint256[] memory _rewardsPaid)
    {
        _rewardTokens = allRewardTokens.values();

        _rewardsPaid = new uint256[](allRewardTokens.length());

        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            _rewardsPaid[i] = userRewards[account][_rewardTokens[i]];
        }
    }

    /**
     * @dev retrieves the stake ids for the specified account
     */
    function stakeIds(address account) public view returns (bytes32[] memory) {
        return userStakes[account].values();
    }

    /**
     * @dev changes the reward wallet
     */
    function setRewardWallet(address wallet) public onlyOwner {
        address old = rewardWallet;

        // if we specify a null address for the reward wallet, then we'll use ourself
        rewardWallet = (wallet != address(0)) ? wallet : address(this);

        emit RewardWalletChanged(old, rewardWallet);
    }

    /**
     * @dev updates the minimum staking time for rewards
     */
    function setMinimumStakingTimeForRewards(uint256 minimumStakingTime) public onlyOwner {
        require(minimumStakingTime >= 900, "must be at least 900 seconds due to block timestamp variations");

        uint256 old = MINIMUM_STAKING_TIME_FOR_REWARDS;
        MINIMUM_STAKING_TIME_FOR_REWARDS = minimumStakingTime;

        emit MinimumStakingTimeChanged(old, minimumStakingTime);
    }

    /**
     * @dev sends the amount of the token specified from the contract to the caller
     */
    function withdraw(IERC20 token, uint256 amount) public onlyOwner {
        token.safeTransfer(_msgSender(), amount);
    }

    /****** STAKING REWARD CLAIMING METHODS ******/

    /**
     * @dev calculates the claimable balance for the given stake ID
     */
    function _claimableBalance(bytes32 stakeId) internal view returns (uint256) {
        StakedNFT memory info = stakedNFTs[stakeId];

        // if they haven't staked long enough, their claimable rewards are 0
        if (block.timestamp < info.stakedTimestamp + MINIMUM_STAKING_TIME_FOR_REWARDS) {
            return 0;
        }

        // calculate how long it's been since the last time they claimed
        uint256 delta = block.timestamp - info.lastClaimTimestamp;

        // calculate how much is claimable based upon the drip rate for the token * the time elapsed
        return rewardTokenDripRate[address(info.rewardToken)] * delta;
    }

    /**
     * @dev returns all of the claimable stakes for the specified account
     */
    function claimable(address account) public view returns (ClaimableInfo[] memory) {
        // retrieve all of the stake ids for the caller
        bytes32[] memory ids = stakeIds(account);

        // construct the temporary claimable information
        ClaimableInfo[] memory claims = new ClaimableInfo[](ids.length);

        // loop through all of the caller's stake ids
        for (uint256 i = 0; i < ids.length; i++) {
            // construct the claimable information structure
            claims[i] = ClaimableInfo({
                stakeId: ids[i],
                rewardToken: address(stakedNFTs[ids[i]].rewardToken),
                amount: _claimableBalance(ids[i])
            });
        }

        return claims;
    }

    /**
     * @dev claims the stake with the given ID
     *
     * Requirements:
     *
     * - Must be owner of the stake id
     */
    function claim(bytes32 stakeId) public {
        _claim(stakeId);
    }

    /**
     * @dev claims all of the available stakes for the specified account
     */
    function claimAll(address account) public {
        // retrieve all of the stake ids for the caller
        bytes32[] memory ids = stakeIds(account);

        // loop through all of the caller's stake ids
        for (uint256 i = 0; i < ids.length; i++) {
            _claim(ids[i]); // process the claim
        }
    }

    /**
     * @dev internal method called when claiming staking rewards
     */
    function _claim(bytes32 stakeId) internal {
        StakedNFT memory info = stakedNFTs[stakeId];

        // get the claimable balance for this stake id
        uint256 _claimableAmount = _claimableBalance(stakeId);

        // if they have nothing to claim, return early (saves gas)
        if (_claimableAmount == 0) {
            return;
        }

        // if we are to pull funds from a reward wallet and it doesn't have permission
        // to use those funds then let's go ahead and return
        if (
            rewardWallet != address(this) && info.rewardToken.allowance(rewardWallet, address(this)) < _claimableAmount
        ) {
            return;
        }

        // update the last claimed timestamp
        stakedNFTs[stakeId].lastClaimTimestamp = block.timestamp;

        // add the reward amount to the total amount for the reward token that we have paid out
        rewardsPaid[address(info.rewardToken)] += _claimableAmount;

        // add the reward amount to the users individual tracking of what we've paid out
        userRewards[info.owner][address(info.rewardToken)] += _claimableAmount;

        if (rewardWallet != address(this)) {
            // transfer the claimable rewards to the owner from the reward wallet
            info.rewardToken.safeTransferFrom(rewardWallet, info.owner, _claimableAmount);
        } else {
            // else, transfer the rewards to the owner from the balance
            // of the token held by the contract
            info.rewardToken.safeTransfer(info.owner, _claimableAmount);
        }

        emit ClaimRewards(stakeId, info.owner, _claimableAmount);
    }

    /****** STAKING METHODS ******/

    function _generateStakeId(
        address owner,
        address nftContract,
        uint256 tokenId
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(owner, nftContract, tokenId, block.timestamp, block.number));
    }

    /**
     * @dev allows a user to stake their NFT into the contract
     *
     * Requirements:
     *
     * - contract must be approved for all NFTs of the owner in the NFT contract
     */
    function stake(
        IERC721 nftContract,
        uint256 tokenId,
        IERC20 rewardToken
    ) public returns (bytes32) {
        require(permittedNFTs.contains(address(nftContract)), "NFT is not permitted to be staked");
        require(permittedRewardTokens.contains(address(rewardToken)), "Reward token is not permitted");
        require(
            nftContract.isApprovedForAll(_msgSender(), address(this)) ||
                nftContract.getApproved(tokenId) == address(this),
            "not permitted to take ownership of NFT for staking"
        );

        // take ownership of the NFT
        nftContract.safeTransferFrom(_msgSender(), address(this), tokenId);

        // generate the stake ID
        bytes32 stakeId = _generateStakeId(_msgSender(), address(nftContract), tokenId);

        // add the stake Id record
        stakedNFTs[stakeId] = StakedNFT({
            stakeId: stakeId,
            owner: _msgSender(),
            nftContract: nftContract,
            tokenId: tokenId,
            stakedTimestamp: block.timestamp,
            lastClaimTimestamp: block.timestamp,
            rewardToken: rewardToken
        });

        // add the stake ID to the user's tracking
        userStakes[_msgSender()].add(stakeId);

        // increment the number of stakes for the given reward token
        stakesPerRewardToken[address(rewardToken)] += 1;

        emit Stake(_msgSender(), address(nftContract), tokenId, address(rewardToken));

        return stakeId;
    }

    /**
     * @dev allows the user to unstake their NFT using the specified stake ID
     */
    function unstake(bytes32 stakeId) public {
        require(stakedNFTs[stakeId].owner == _msgSender(), "not the owner of the specified stake id"); // this also implicitly requires that the stake id exists

        // pull the staked NFT info
        StakedNFT memory info = stakedNFTs[stakeId];

        // claim before unstake
        _claim(stakeId);

        // delete the record
        delete stakedNFTs[stakeId];

        // delete the stake ID from the user's tracking
        userStakes[info.owner].remove(stakeId);

        // decrement the number of stakes for the given reward token
        stakesPerRewardToken[address(info.rewardToken)] -= 1;

        // transfer the NFT back to the user
        info.nftContract.safeTransferFrom(address(this), info.owner, info.tokenId);

        emit UnStake(info.owner, address(info.nftContract), info.tokenId, address(info.rewardToken));
    }

    /****** MANAGEMENT OF PERMITTED REWARD TOKENS ******/

    function isPermittedRewardToken(address token) public view returns (bool) {
        return permittedRewardTokens.contains(token);
    }

    /**
     * @dev returns an array of the permitted reward tokens
     */
    function rewardTokens() public view returns (address[] memory) {
        return permittedRewardTokens.values();
    }

    /**
     * @dev adds the specified token as a permitted reward token at the specified drip rate
     *
     * WARNING: amountOfTokenPerDayPerNFT is expressed as the amount of the token to
     *          drip per day per NFT expressed in atomic units (gwei)
     *          ex. FTM has 18 decimals; therefore,
     *          1.0 FTM = 1000000000000000000 atomic units
     *          a dripRate of 1 would drip 0.000000000000000001 a second per NFT
     *
     */
    function permitRewardToken(address token, uint256 amountOfTokenPerDayPerNFT) public onlyOwner {
        require(!permittedRewardTokens.contains(token), "Reward token is already permitted");

        permittedRewardTokens.add(token);

        // keeps track of all tokens that have been permitted in the past
        // so that we can track all payouts for all rewards tokens for users
        // as such, we only want to add it to the set once in case it is added
        // again later after it has been removed
        if (!allRewardTokens.contains(token)) {
            allRewardTokens.add(token);
        }

        // set the drip rate based upon the amount released per day divided by the seconds in a day
        rewardTokenDripRate[token] = amountOfTokenPerDayPerNFT / 24 hours;

        require(rewardTokenDripRate[token] != 0, "amountOfTokenPerDayPerNFT results in a zero (0) drip rate");

        emit PermittedRewardToken(token, rewardTokenDripRate[token]);
    }

    /**
     * @dev updates the drip rate for the given token to the specified value
     *
     * WARNING: amountOfTokenPerDayPerNFT is expressed as the amount of the token to
     *          drip per day per NFT expressed in atomic units (gwei)
     *          ex. FTM has 18 decimals; therefore,
     *          1.0 FTM = 1000000000000000000 atomic units
     *          a dripRate of 1 would drip 0.000000000000000001 a second per NFT
     *
     */
    function setRewardTokenDripRate(address token, uint256 amountOfTokenPerDayPerNFT) public onlyOwner {
        require(permittedRewardTokens.contains(token), "Reward token is not permitted");

        uint256 old = rewardTokenDripRate[token];

        // set the drip rate based upon the amount released per day divided by the seconds in a day
        rewardTokenDripRate[token] = amountOfTokenPerDayPerNFT / 24 hours;

        require(rewardTokenDripRate[token] != 0, "amountOfTokenPerDayPerNFT results in a zero (0) drip rate");

        emit ChangeDripRate(token, old, rewardTokenDripRate[token]);
    }

    /**
     * @dev removes the specified token from the permitted reward token list
     *
     * WARNING: If a user still has a staked NFT for the reward token
     *          their selected reward token will not switch to something
     *          else and they will still be able to claim the drip rewards
     *          assuming that the reward wallet has enough of a balance of
     *          the token to do pay it out. This method simply stops letting
     *          users select the reward token as the reward for staking their NFT
     *
     * Requirements:
     *
     * - Token must not be currently used by a staked user
     */
    function denyRewardToken(address token) public onlyOwner {
        require(permittedRewardTokens.contains(token), "Reward token is not permitted");

        uint256 dripRate = rewardTokenDripRate[token];

        permittedRewardTokens.remove(token);

        emit DeniedRewardToken(token, dripRate);
    }

    /****** MANAGEMENT OF PERMITTED NFTs ******/

    function isPermittedNFT(address nftContract) public view returns (bool) {
        return permittedNFTs.contains(nftContract);
    }

    /**
     * @dev returns an array of the permitted NFTs
     */
    function nfts() public view returns (address[] memory) {
        return permittedNFTs.values();
    }

    /**
     * @dev adds the specified nft contract as an acceptable NFT for staking purposes
     */
    function permitNFT(address nftContract) public onlyOwner {
        require(!permittedNFTs.contains(nftContract), "NFT already permitted");

        permittedNFTs.add(nftContract);

        emit PermittedNFTContract(nftContract);
    }

    /**
     * @dev removes the specified nft contract from being an acceptable NFT for staking purposes
     */
    function denyNFT(address nftContract) public onlyOwner {
        require(permittedNFTs.contains(nftContract), "NFT is not permitted");

        permittedNFTs.remove(nftContract);

        emit DeniedNFTContract(nftContract);
    }

    /**
     * @dev handles IERC721.safeTransferFrom()
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public override returns (bytes4) {
        require(operator == address(this), "Cannot send tokens to contract directly");

        emit ReceivedERC721(operator, from, tokenId, data, gasleft());

        return IERC721Receiver.onERC721Received.selector;
    }
}
