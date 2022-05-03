// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../../@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../../@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../../@openzeppelin/contracts/access/Ownable.sol";

contract ERC721Drip is IERC721Receiver, Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    event ChangeRewardWallet(address indexed _old, address indexed _new);
    event Claim(bytes32 indexed stakeId, address indexed owner, address indexed token, uint256 amount);
    event ConfigureCollection(address indexed collection, address indexed reward, uint256 indexed dripRate);
    event DisableCollection(address indexed collection);
    event ReceivedERC721(address operator, address from, uint256 tokenId, bytes data, uint256 gas);
    event SetMinimumSTakingTime(uint256 indexed _old, uint256 indexed _new);
    event Stake(address indexed owner, address indexed collection, uint256 indexed tokenId, bytes32 stakeId);
    event Unstake(address indexed owner, address indexed collection, uint256 indexed tokenId, bytes32 stakeId);

    struct ClaimableInfo {
        bytes32 stakeId;
        address token;
        uint256 amount;
    }

    // contains the permitted NFTs
    EnumerableSet.AddressSet private permittedERC721s;

    struct PermittedERC721 {
        address dripToken;
        uint256 dripRate;
    }
    mapping(address => PermittedERC721) public tokenRewards;

    struct StakedNFT {
        bytes32 stakeId;
        address owner;
        address collection;
        uint256 tokenId;
        uint256 stakedTimestamp;
        uint256 lastClaimTimestamp;
    }
    mapping(bytes32 => StakedNFT) public stakedNFTs;
    mapping(address => EnumerableSet.Bytes32Set) private userStakes;

    address public rewardWallet;
    uint256 public MINIMUM_STAKING_TIME = 24 hours;

    /****** CONSTRUCTOR ******/

    constructor(address _rewardWallet) {
        rewardWallet = (_rewardWallet != address(0)) ? _rewardWallet : address(this);
        emit ChangeRewardWallet(address(0), rewardWallet);
    }

    /****** PUBLIC METHODS ******/

    function claim(bytes32 stakeId) public {
        _claim(stakeId, true);
    }

    function claimable(bytes32 stakeId) public view returns (ClaimableInfo memory) {
        require(stakedNFTs[stakeId].collection != address(0), "stake does not exist");

        return ClaimableInfo({ stakeId: stakeId, token: rewardToken(stakeId), amount: _claimableBalance(stakeId) });
    }

    function claimables(address account) public view returns (ClaimableInfo[] memory) {
        bytes32[] memory ids = stakeIds(account);

        ClaimableInfo[] memory claims = new ClaimableInfo[](ids.length);

        // loop through the staked NFTs to get the claimable information
        for (uint256 i = 0; i < ids.length; i++) {
            claims[i] = ClaimableInfo({
                stakeId: ids[i],
                token: rewardToken(ids[i]),
                amount: _claimableBalance(ids[i])
            });
        }

        return claims;
    }

    function claimAll(address account) public {
        // retrieve all of the stake ids for the caller
        bytes32[] memory ids = stakeIds(account);

        // loop through all of our caller's stake ids
        for (uint256 i = 0; i < ids.length; i++) {
            _claim(ids[i], true); // process the claim
        }
    }

    function isPermitted(address collection) public view returns (bool) {
        return permittedERC721s.contains(collection);
    }

    function nfts() public view returns (address[] memory) {
        return permittedERC721s.values();
    }

    function rewardRate(bytes32 stakeId) public view returns (uint256) {
        return tokenRewards[stakedNFTs[stakeId].collection].dripRate;
    }

    function rewardToken(bytes32 stakeId) public view returns (address) {
        return tokenRewards[stakedNFTs[stakeId].collection].dripToken;
    }

    function stake(IERC721 collection, uint256[] memory tokenIds) public returns (bytes32[] memory) {
        require(permittedERC721s.contains(address(collection)), "collection not permitted");
        require(collection.isApprovedForAll(_msgSender(), address(this)), "not permitted to manage collection");

        bytes32[] memory _stakeIds = new bytes32[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            // take possession of the token
            collection.safeTransferFrom(_msgSender(), address(this), tokenIds[i]);

            // generate the stake ID
            bytes32 stakeId = _generateStakeId(_msgSender(), address(collection), tokenIds[i]);

            // add the stake ID record
            stakedNFTs[stakeId] = StakedNFT({
                stakeId: stakeId,
                owner: _msgSender(),
                collection: address(collection),
                tokenId: tokenIds[i],
                stakedTimestamp: block.timestamp,
                lastClaimTimestamp: block.timestamp
            });

            // add the stake ID to the user's tracking
            userStakes[_msgSender()].add(stakeId);

            _stakeIds[i] = stakeId;

            emit Stake(_msgSender(), address(collection), tokenIds[i], stakeId);
        }

        return _stakeIds;
    }

    function staked(address account) public view returns (StakedNFT[] memory) {
        bytes32[] memory ids = stakeIds(account);

        StakedNFT[] memory stakes = new StakedNFT[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
            stakes[i] = stakedNFTs[ids[i]];
        }

        return stakes;
    }

    function stakeIds(address account) public view returns (bytes32[] memory) {
        return userStakes[account].values();
    }

    function unstake(bytes32[] memory _stakeIds, bool requiredClaim) public {
        for (uint256 i = 0; i < _stakeIds.length; i++) {
            bytes32 stakeId = _stakeIds[i];
            require(stakedNFTs[stakeId].owner == _msgSender(), "not owner of stake id");

            // pull the record
            StakedNFT memory info = stakedNFTs[stakeId];

            // claim before unstake
            _claim(stakeId, requiredClaim);

            // delete the record
            delete stakedNFTs[stakeId];

            // delete the ID from the user's tracking
            userStakes[info.owner].remove(stakeId);

            // transfer the NFT back to the user
            IERC721(info.collection).safeTransferFrom(address(this), info.owner, info.tokenId);

            emit Unstake(info.owner, info.collection, info.tokenId, stakeId);
        }
    }

    /****** MANAGEMENT METHODS ******/

    function configureCollection(
        address collection,
        address reward,
        uint256 amountOfTokenPerDay
    ) public onlyOwner {
        uint256 dripRate = amountOfTokenPerDay / 24 hours;
        require(dripRate != 0, "amountOfTokenPerDay results in a zero (0) drip rate");
        tokenRewards[collection] = PermittedERC721({ dripToken: reward, dripRate: dripRate });

        if (!permittedERC721s.contains(collection)) {
            permittedERC721s.add(collection);
        }

        emit ConfigureCollection(collection, reward, dripRate);
    }

    function disableCollection(address collection) public onlyOwner {
        require(permittedERC721s.contains(collection), "Collection not configured");
        permittedERC721s.remove(collection);
        emit DisableCollection(collection);
    }

    function setMinimumStakingTime(uint256 minimumStakingTime) public onlyOwner {
        require(minimumStakingTime >= 900, "must be at least 900 seconds");
        uint256 old = MINIMUM_STAKING_TIME;
        MINIMUM_STAKING_TIME = minimumStakingTime;
        emit SetMinimumSTakingTime(old, minimumStakingTime);
    }

    function setRewardWallet(address _rewardWallet) public onlyOwner {
        address old = rewardWallet;
        rewardWallet = (_rewardWallet != address(0)) ? _rewardWallet : address(this);
        emit ChangeRewardWallet(old, _rewardWallet);
    }

    function withdraw(address token, uint256 amount) public onlyOwner {
        IERC20(token).safeTransfer(_msgSender(), amount);
    }

    /****** INTERNAL METHODS ******/

    function _claim(bytes32 stakeId, bool required) internal {
        StakedNFT storage info = stakedNFTs[stakeId];

        // get he claimable balance for this stake ID
        uint256 _claimableAmount = _claimableBalance(stakeId);

        // if they have nothing to claim, exit early to save gas
        if (_claimableAmount == 0) {
            return;
        }

        IERC20 token = IERC20(rewardToken(stakeId));

        // if we are to pull funds from a reward wallet and it doesn't have permission
        // to use those funds then let's go ahead and return
        if (rewardWallet != address(this) && token.allowance(rewardWallet, address(this)) < _claimableAmount) {
            if (required) {
                revert("contract not authorized for claimable amount, contact the team");
            } else {
                return;
            }
        }

        // update the last claimed timestamp
        info.lastClaimTimestamp = block.timestamp;

        if (rewardWallet != address(this)) {
            // transfer the claimable rewards to the owner from the reward wallet
            token.safeTransferFrom(rewardWallet, info.owner, _claimableAmount);
        } else {
            // else, transfer the rewards to the owner from the balance of the token held by the contract
            token.safeTransfer(info.owner, _claimableAmount);
        }

        emit Claim(stakeId, info.owner, address(token), _claimableAmount);
    }

    function _claimableBalance(bytes32 stakeId) internal view returns (uint256) {
        StakedNFT memory info = stakedNFTs[stakeId];

        // if they haven't staked long enough, their claimable rewards are 0
        if (block.timestamp < info.stakedTimestamp + MINIMUM_STAKING_TIME) {
            return 0;
        }

        // calculate how long it's been since the last time they claimed
        uint256 delta = block.timestamp - info.lastClaimTimestamp;

        // calculate how much is claimable based upon the drip rate for the token * the time elapsed
        return rewardRate(stakeId) * delta;
    }

    function _generateStakeId(
        address owner,
        address collection,
        uint256 tokenId
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(owner, collection, tokenId, block.timestamp, block.number));
    }

    /****** REQUIRED METHODS ******/

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
