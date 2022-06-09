// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../abstracts/Cloneable.sol";
import "../libraries/ERC20Helper.sol";

contract ERC20AdvancedDrip is Ownable, Cloneable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using ERC20Helper for address;

    event ChangeRewardWallet(address indexed _old, address indexed _new);
    event Claim(address indexed account, address indexed asset, address indexed reward, uint256 amount);
    event ConfigureAsset(address indexed asset, address indexed reward, uint256 indexed amountOfTokenPerDay);
    event DisableAsset(address indexed asset);
    event SetMaximumStakingTime(uint256 indexed _old, uint256 indexed _new);
    event SetMinimumStakingTime(uint256 indexed _old, uint256 indexed _new);
    event Stake(address indexed account, address indexed asset, uint256 indexed amount);
    event Unstake(address indexed account, address indexed asset, uint256 indexed amount);

    struct ClaimableInfo {
        address asset;
        address reward;
        uint256 amount;
    }

    // holds the currently permitted ERC20s for new staking
    EnumerableSet.AddressSet private permittedERC20s;
    EnumerableSet.AddressSet private knownAssets;

    struct RewardInfo {
        IERC20 dripToken;
        uint256 dripRate;
        uint256 staked;
    }
    mapping(address => RewardInfo) public assetRewards; // asset => reward

    struct UserStakeInfo {
        address asset;
        uint256 balance;
        uint256 stakedTimestamp;
        uint256 lastClaimTimestamp;
    }
    mapping(address => mapping(address => UserStakeInfo)) public stakeInfo; // account[asset] => stake
    mapping(address => EnumerableSet.AddressSet) private userStakes; // account => stakedAssets[]

    address public rewardWallet;
    uint256 public MAXIMUM_STAKING_TIME = 3 days;
    uint256 public MINIMUM_STAKING_TIME = 24 hours;

    /****** CONSTRUCTOR ******/

    constructor() {
        _transferOwnership(address(0));
    }

    function intialize() public initializer {}

    function initialize(address _rewardWallet) public initializer {
        require(_rewardWallet != address(0), "Reward wallet cannot be null address");
        _transferOwnership(_msgSender());
        setMaximumStakingTime(3 days);
        setMinimumStakingTime(24 hours);

        rewardWallet = _rewardWallet;
        emit ChangeRewardWallet(address(0), rewardWallet);
    }

    /****** PUBLIC METHODS ******/

    function assets() public view returns (address[] memory) {
        return knownAssets.values();
    }

    function claim(
        address account,
        address asset,
        bool requiredClaim
    ) public {
        _claim(account, asset, requiredClaim);
    }

    function claimable(address account, address asset) public view returns (ClaimableInfo memory) {
        return ClaimableInfo({ asset: asset, reward: rewardToken(asset), amount: _claimableBalance(account, asset) });
    }

    function claimables(address account) public view returns (ClaimableInfo[] memory) {
        // retrieve all of the staked assets for the caller
        address[] memory _assets = userStakes[account].values();

        ClaimableInfo[] memory claims = new ClaimableInfo[](_assets.length);

        for (uint256 i = 0; i < _assets.length; i++) {
            claims[i] = ClaimableInfo({
                asset: _assets[i],
                reward: rewardToken(_assets[i]),
                amount: _claimableBalance(account, _assets[i])
            });
        }

        return claims;
    }

    function claimAll(address account, bool requiredClaim) public {
        // retrieve all of the staked assets for the caller
        address[] memory _assets = userStakes[account].values();

        // loop through all of our caller's staked assets
        for (uint256 i = 0; i < _assets.length; i++) {
            _claim(account, _assets[i], requiredClaim);
        }
    }

    function isPermitted(address asset) public view returns (bool) {
        return permittedERC20s.contains(asset);
    }

    function rewardRate(address asset) public view returns (uint256) {
        if (assetRewards[asset].staked == 0) {
            return 0;
        }

        // calculates the rate per unit for the staked asset
        // ie. $50 per day is $0.000578703703704 per second
        // 0.000578703703704 per second / 100 units staked = $0.000005787037037 per unit per second
        return (assetRewards[asset].dripRate / asset.weiToWholeUnits(assetRewards[asset].staked));
    }

    function rewardToken(address asset) public view returns (address) {
        return address(assetRewards[asset].dripToken);
    }

    function stake(
        address account,
        address asset,
        uint256 amount,
        bool requiredClaim
    ) public {
        require(permittedERC20s.contains(asset), "ERC20 not permitted");
        require(amount != 0, "amount must not be 0");

        // claim before staking more
        _claim(account, asset, requiredClaim);

        // caller pays regardless of the account the stake is recorded for
        IERC20(asset).safeTransferFrom(_msgSender(), address(this), amount);

        // increment the amount staked of this asset
        assetRewards[asset].staked += amount;

        stakeInfo[account][asset] = UserStakeInfo({
            asset: asset,
            lastClaimTimestamp: block.timestamp,
            stakedTimestamp: block.timestamp,
            balance: stakeInfo[account][asset].balance + amount
        });

        // add it to tracking if enabled
        if (!userStakes[account].contains(asset)) {
            userStakes[account].add(asset);
        }

        emit Stake(account, asset, amount);
    }

    function staked(address account) public view returns (UserStakeInfo[] memory) {
        // retrieve all of the staked assets for the caller
        address[] memory _assets = userStakes[account].values();

        UserStakeInfo[] memory stakes = new UserStakeInfo[](_assets.length);

        for (uint256 i = 0; i < _assets.length; i++) {
            stakes[i] = stakeInfo[account][_assets[i]];
        }

        return stakes;
    }

    function unstake(
        address asset,
        uint256 amount,
        bool requiredClaim
    ) public {
        require(amount != 0, "amount cannot be 0");
        // pull the record
        UserStakeInfo memory info = stakeInfo[_msgSender()][asset];
        require(amount <= info.balance, "cannot request to unstake more than staked");

        // claim before unstake
        _claim(_msgSender(), asset, requiredClaim);

        // update the record
        info.balance -= amount;

        if (info.balance == 0) {
            delete stakeInfo[_msgSender()][asset];
            userStakes[_msgSender()].remove(asset);
        }

        // decrement the amount staked of this asset
        assetRewards[asset].staked -= amount;

        // transfer the amount back to the owner of the staked assets
        IERC20(asset).safeTransfer(_msgSender(), amount);

        emit Unstake(_msgSender(), asset, amount);
    }

    /****** MANAGEMENT METHODS ******/

    function configureStakeableAsset(
        address asset,
        address reward,
        uint256 amountOfTokenPerDay
    ) public onlyOwner {
        require(asset != address(0), "asset cannot be null address");
        require(reward != address(0), "reward cannot be null address");

        assetRewards[asset] = RewardInfo({
            dripToken: IERC20(reward),
            dripRate: amountOfTokenPerDay / 24 hours,
            staked: assetRewards[asset].staked
        });

        if (!permittedERC20s.contains(asset)) {
            permittedERC20s.add(asset);
        }

        if (!knownAssets.contains(asset)) {
            knownAssets.add(asset);
        }

        emit ConfigureAsset(asset, reward, amountOfTokenPerDay);
    }

    function disableStakeableAsset(address asset) public onlyOwner {
        require(permittedERC20s.contains(asset), "asset not configured");
        permittedERC20s.remove(asset);
        emit DisableAsset(asset);
    }

    function setMaximumStakingTime(uint256 maximumStakingTime) public onlyOwner {
        require(maximumStakingTime >= MINIMUM_STAKING_TIME, "max must be greater than min");
        require(maximumStakingTime <= 30 days, "max must not exceed 30 days");
        uint256 old = MAXIMUM_STAKING_TIME;
        MAXIMUM_STAKING_TIME = maximumStakingTime;
        emit SetMaximumStakingTime(old, maximumStakingTime);
    }

    function setMinimumStakingTime(uint256 minimumStakingTime) public onlyOwner {
        require(minimumStakingTime >= 900, "must be at least 900 seconds");
        require(minimumStakingTime <= MAXIMUM_STAKING_TIME, "min must be less than max");
        uint256 old = MINIMUM_STAKING_TIME;
        MINIMUM_STAKING_TIME = minimumStakingTime;
        emit SetMinimumStakingTime(old, minimumStakingTime);
    }

    function setRewardWallet(address _rewardWallet) public onlyOwner {
        require(_rewardWallet != address(0), "Reward wallet cannot be null address");
        require(_rewardWallet != address(this), "Reward wallet cannot be this address");
        address old = rewardWallet;
        rewardWallet = _rewardWallet;
        emit ChangeRewardWallet(old, _rewardWallet);
    }

    /****** INTERNAL METHODS ******/

    function _claim(
        address account,
        address asset,
        bool required
    ) internal {
        // get the claimable balance for this account and asset
        uint256 _claimableAmount = _claimableBalance(account, asset);

        // if they have nothing to claim, exit early to save gas
        if (_claimableAmount == 0) {
            return;
        }

        // if we are to pull funds and it doesn't have the permission
        // to use those funds then let's go ahead and return
        if (
            rewardWallet != address(this) &&
            assetRewards[asset].dripToken.allowance(rewardWallet, address(this)) < _claimableAmount &&
            assetRewards[asset].dripToken.balanceOf(rewardWallet) >= _claimableAmount
        ) {
            if (required) {
                revert("contract not authorized for claimable amount, contact the team");
            } else {
                return;
            }
        }

        // update the last claimed timestamp
        stakeInfo[account][asset].lastClaimTimestamp = block.timestamp;

        // transfer the claimable rewards to the owner from the reward wallet
        assetRewards[asset].dripToken.safeTransferFrom(rewardWallet, account, _claimableAmount);

        emit Claim(account, asset, address(assetRewards[asset].dripToken), _claimableAmount);
    }

    function _claimableBalance(address account, address asset) internal view returns (uint256) {
        // if they haven't staked long enough, their claimable rewards are 0
        if (block.timestamp < stakeInfo[account][asset].stakedTimestamp + MINIMUM_STAKING_TIME) {
            return 0;
        }

        // calculate how long it's been since the last time they claimed
        uint256 delta = block.timestamp - stakeInfo[account][asset].lastClaimTimestamp;

        // cap the stake at the maximum allowable
        if (delta > MAXIMUM_STAKING_TIME) {
            delta = MAXIMUM_STAKING_TIME;
        }

        // calculate how much is claimable as the product of the rate, time, and amount staked
        return rewardRate(asset) * delta * asset.weiToWholeUnits(stakeInfo[account][asset].balance);
    }
}
