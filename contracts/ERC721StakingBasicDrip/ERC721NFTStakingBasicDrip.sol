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

    event Stake(
        address indexed owner,
        address indexed nftContract,
        uint256 indexed tokenId,
        address rewardToken
    );
    event UnStake(
        address indexed owner,
        address indexed nftContract,
        uint256 indexed tokenId,
        address rewardToken
    );
    event RewardWalletChanged(
        address indexed oldRewardWallet,
        address indexed newRewardWallet
    );
    event MinimumStakingTimeChanged(uint256 indexed oldTime, uint256 newTime);
    event PermittedRewardToken(address indexed token, uint256 dripRate);
    event ChangeDripRate(
        address indexed token,
        uint256 oldDripRate,
        uint256 newDripRate
    );
    event DeniedRewardToken(address indexed token, uint256 dripRate);
    event PermittedNFTContract(address indexed nftContract);
    event DeniedNFTContract(address indexed nftContract);
    event ClaimRewards(
        bytes32 indexed stakeId,
        address indexed owner,
        uint256 indexed amount
    );
    event ReceivedERC721(
        address operator,
        address from,
        uint256 tokenId,
        bytes data,
        uint256 gas
    );

    // holds the list of permitted NFTs
    EnumerableSet.AddressSet private permittedNFTs;

    // holds the list of permitted reward tokens
    EnumerableSet.AddressSet private permittedRewardTokens;

    // holds the reward token drip rate
    mapping(address => uint256) public rewardTokenDripRate;

    struct StakedNFT {
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

    // holds the number of staked NFTs per reward token
    mapping(address => uint256) public stakesPerRewardToken;

    // holds the amount of rewards paid by reward token
    mapping(address => uint256) public rewardsPaid;

    // holds the address of the wallet that contains the staking rewards
    address public rewardWallet;

    // the minimum amount of time required before claiming rewards via the drip
    uint256 public MINIMUM_STAKING_TIME_FOR_REWARDS;

    constructor(address _rewardWallet) {
        rewardWallet = _rewardWallet;

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

        _runwaySeconds = _balance / _runRatePerSecond;

        _runwayDays = _runwaySeconds / 24 hours;
    }

    /**
     * @dev returns an array of all staked NFT for the caller
     */
    function staked() public view returns (StakedNFT[] memory) {
        // retrieve all of the stake ids for the caller
        bytes32[] memory ids = stakeIds(_msgSender());

        // construct the temporary staked information
        StakedNFT[] memory stakes = new StakedNFT[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
            stakes[i] = stakedNFTs[ids[i]];
        }

        return stakes;
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
        rewardWallet = wallet;

        emit RewardWalletChanged(old, wallet);
    }

    /**
     * @dev updates the minimum staking time for rewards
     */
    function setMinimumStakingTimeForRewards(uint256 minimumStakingTime)
        public
        onlyOwner
    {
        require(
            minimumStakingTime >= 900,
            "must be at least 900 seconds due to block timestamp variations"
        );

        uint256 old = MINIMUM_STAKING_TIME_FOR_REWARDS;
        MINIMUM_STAKING_TIME_FOR_REWARDS = minimumStakingTime;

        emit MinimumStakingTimeChanged(old, minimumStakingTime);
    }

    /****** STAKING REWARD CLAIMING METHODS ******/

    /**
     * @dev calculates the claimable balance for the given stake ID
     */
    function _claimableBalance(bytes32 stakeId)
        internal
        view
        returns (uint256)
    {
        StakedNFT memory info = stakedNFTs[stakeId];

        // if they haven't staked long enough, their claimable rewards are 0
        if (
            block.timestamp <
            info.stakedTimestamp + MINIMUM_STAKING_TIME_FOR_REWARDS
        ) {
            return 0;
        }

        // calculate how long it's been since the last time they claimed
        uint256 delta = block.timestamp - info.lastClaimTimestamp;

        // calculate how much is claimable based upon the drip rate for the token * the time elapsed
        return rewardTokenDripRate[address(info.rewardToken)] * delta;
    }

    /**
     * @dev returns all of the claimable stakes for the caller
     */
    function claimable() public view returns (ClaimableInfo[] memory) {
        // retrieve all of the stake ids for the caller
        bytes32[] memory ids = stakeIds(_msgSender());

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
     * @dev claims all of the available stakes for the caller
     */
    function claimAll() public {
        // retrieve all of the stake ids for the caller
        bytes32[] memory ids = stakeIds(_msgSender());

        // loop through all of the caller's stake ids
        for (uint256 i = 0; i < ids.length; i++) {
            // only try to claim if they have a claimable balance (saves gas)
            if (_claimableBalance(ids[i]) != 0) {
                _claim(ids[i]); // process the claim
            }
        }
    }

    /**
     * @dev internal method called when claiming staking rewards
     */
    function _claim(bytes32 stakeId) internal {
        require(
            stakedNFTs[stakeId].owner == _msgSender(),
            "not the owner of the specified stake id"
        );

        StakedNFT memory info = stakedNFTs[stakeId];

        // get the claimable balance for this stake id
        uint256 _claimableAmount = _claimableBalance(stakeId);

        require(
            info.rewardToken.allowance(rewardWallet, address(this)) >=
                _claimableAmount,
            "contract not authorized for claimable amount, contact the team"
        );

        // update the last claimed timestamp
        stakedNFTs[stakeId].lastClaimTimestamp = block.timestamp;

        // transfer the claimable rewards to the caller
        info.rewardToken.safeTransferFrom(
            rewardWallet,
            _msgSender(),
            _claimableAmount
        );

        rewardsPaid[address(info.rewardToken)] += _claimableAmount;

        emit ClaimRewards(stakeId, _msgSender(), _claimableAmount);
    }

    /****** STAKING METHODS ******/

    function _generateStakeId(
        address owner,
        address nftContract,
        uint256 tokenId
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    owner,
                    nftContract,
                    tokenId,
                    block.timestamp,
                    block.number
                )
            );
    }

    /**
     * @dev allows a user to stake their NFT into the contract
     *
     * Requirements:
     *
     * - contract must be approved to transfer the NFT
     */
    function stake(
        IERC721 nftContract,
        uint256 tokenId,
        IERC20 rewardToken
    ) public returns (bytes32) {
        require(
            permittedNFTs.contains(address(nftContract)),
            "NFT is not permitted to be staked"
        );
        require(
            permittedRewardTokens.contains(address(rewardToken)),
            "Reward token is not permitted"
        );
        require(
            nftContract.getApproved(tokenId) == address(this),
            "not permitted to take ownership of NFT for staking"
        );

        // take ownership of the NFT
        nftContract.safeTransferFrom(_msgSender(), address(this), tokenId);

        // generate the stake ID
        bytes32 stakeId = _generateStakeId(
            _msgSender(),
            address(nftContract),
            tokenId
        );

        // add the stake Id record
        stakedNFTs[stakeId] = StakedNFT({
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

        emit Stake(
            _msgSender(),
            address(nftContract),
            tokenId,
            address(rewardToken)
        );

        return stakeId;
    }

    /**
     * @dev allows the user to unstake their NFT using the specified stake ID
     */
    function unstake(bytes32 stakeId) public {
        require(
            stakedNFTs[stakeId].owner == _msgSender(),
            "not the owner of the specified stake id"
        );

        // pull the staked NFT info
        StakedNFT memory info = stakedNFTs[stakeId];

        // delete the record
        delete stakedNFTs[stakeId];

        // delete the stake ID from the user's tracking
        userStakes[_msgSender()].remove(stakeId);

        // decrement the number of stakes for the given reward token
        stakesPerRewardToken[address(info.rewardToken)] -= 1;

        // transfer the NFT back to the user
        info.nftContract.safeTransferFrom(
            address(this),
            _msgSender(),
            info.tokenId
        );

        emit UnStake(
            info.owner,
            address(info.nftContract),
            info.tokenId,
            address(info.rewardToken)
        );
    }

    /****** MANAGEMENT OF PERMITTED REWARD TOKENS ******/

    function isPermittedRewardToken(address token) public view returns (bool) {
        return permittedRewardTokens.contains(token);
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
    function permitRewardToken(address token, uint256 amountOfTokenPerDayPerNFT)
        public
        onlyOwner
    {
        require(
            !permittedRewardTokens.contains(token),
            "Reward token is already permitted"
        );

        permittedRewardTokens.add(token);

        // set the drip rate based upon the amount released per day divided by the seconds in a day
        rewardTokenDripRate[token] = amountOfTokenPerDayPerNFT / 24 hours;

        require(
            rewardTokenDripRate[token] != 0,
            "amountOfTokenPerDayPerNFT results in a zero (0) drip rate"
        );

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
    function setRewardTokenDripRate(
        address token,
        uint256 amountOfTokenPerDayPerNFT
    ) public onlyOwner {
        require(
            permittedRewardTokens.contains(token),
            "Reward token is not permitted"
        );

        uint256 old = rewardTokenDripRate[token];

        // set the drip rate based upon the amount released per day divided by the seconds in a day
        rewardTokenDripRate[token] = amountOfTokenPerDayPerNFT / 24 hours;

        require(
            rewardTokenDripRate[token] != 0,
            "amountOfTokenPerDayPerNFT results in a zero (0) drip rate"
        );

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
        require(
            permittedRewardTokens.contains(token),
            "Reward token is not permitted"
        );

        uint256 dripRate = rewardTokenDripRate[token];

        permittedRewardTokens.remove(token);

        emit DeniedRewardToken(token, dripRate);
    }

    /****** MANAGEMENT OF PERMITTED NFTs ******/

    function isPermittedNFT(address nftContract) public view returns (bool) {
        return permittedNFTs.contains(nftContract);
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
        require(
            operator == address(this),
            "Cannot send tokens to contract directly"
        );

        emit ReceivedERC721(operator, from, tokenId, data, gasleft());

        return IERC721Receiver.onERC721Received.selector;
    }
}
