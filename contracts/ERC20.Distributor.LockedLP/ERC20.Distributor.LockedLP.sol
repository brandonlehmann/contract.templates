// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../@openzeppelin/contracts/utils/Context.sol";
import "../../@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../../@openzeppelin/contracts/interfaces/IERC1271.sol";
import "../../@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interfaces/IERC20.gTRTL.sol";
import "../interfaces/IgTRTLCalculator.sol";

interface ISnapshotDelegation {
    function setDelegate(string memory space, address delegate) external;
}

contract ERC20DistributorLockedToken is Context, IERC1271 {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    using ECDSA for bytes32;

    event Staked(
        address indexed owner,
        address indexed token,
        uint256 indexed amount,
        uint256 rewardAmount,
        uint256 createdAt,
        uint256 unlockAt
    );
    event UnStaked(
        address indexed owner,
        address indexed token,
        uint256 indexed amount,
        uint256 rewardAmount,
        uint256 createdAt,
        uint256 unlockAt
    );
    event PermitToken(address indexed token, address indexed gTRTLCalculator);
    event DenyToken(address indexed token, address indexed gTRTLCalculator);
    event UpdateLockBonus(
        StakeLength indexed length,
        uint256 oldBonus,
        uint256 newBonus
    );
    event DelegateUpdated(
        address indexed delegateContract,
        string space,
        address delegate
    );

    gTRTL public constant token =
        gTRTL(0xA064e15e284D5D288281cc24d94DD8ed39d42AA4);

    modifier onlyPolicy() {
        require(
            token.hasRole(token.POLICY_ROLE(), _msgSender()),
            "policy access violation"
        );
        _;
    }

    enum StakeLength {
        WEEK,
        MONTH,
        QUARTER,
        YEAR
    }

    struct Stake {
        address owner;
        IERC20 token;
        uint256 amount;
        uint256 rewardAmount;
        uint256 createdAt;
        uint256 unlockAt;
    }

    mapping(bytes32 => Stake) public stakeInfo;

    mapping(address => EnumerableSet.Bytes32Set) private _userStakes;

    mapping(address => IgTRTLCalculator) public permittedTokens;

    // stake bonus is stored in basis points
    mapping(StakeLength => uint256) public stakeBonusForLength;

    modifier isPermittedToken(address _token) {
        require(
            address(permittedTokens[_token]) != address(0),
            "Not a permitted token"
        );
        _;
    }

    /****** MANAGEMENT METHODS ******/

    /**
     * @dev permits the specified token for staking in the contract
     * whose value in reward token is derived from the calculator address
     * the calculator allows us to hook up different LP types in the future
     * (ie. Uniswap, Balancer, or normal ERC20)
     */
    function permitToken(address _token, address calculator) public onlyPolicy {
        require(
            address(permittedTokens[_token]) == address(0),
            "LP Token is already permitted"
        );
        permittedTokens[_token] = IgTRTLCalculator(calculator);
        emit PermitToken(_token, calculator);
    }

    /**
     * @dev denies the specified token from staking in the contract
     */
    function denyToken(address _token) public onlyPolicy {
        require(
            address(permittedTokens[_token]) != address(0),
            "LP Token is not currently permitted"
        );
        address calculator = address(permittedTokens[_token]);
        delete permittedTokens[_token];
        emit DenyToken(_token, calculator);
    }

    /**
     * @dev sets the delegate address for this contract for the space specified
     * to the delegate specified for the provided space
     *
     * For more information, see: https://docs.snapshot.org/guides/delegation
     */
    function setDelegate(
        address _delegateContract,
        string memory space,
        address delegate
    ) public onlyPolicy {
        ISnapshotDelegation(_delegateContract).setDelegate(space, delegate);
        emit DelegateUpdated(_delegateContract, space, delegate);
    }

    /**
     * @dev sets the lock bonus in basis points for the specified lock length
     * bonusBasis is in basis points. 500 = 5%
     */
    function setLockBonus(StakeLength lockLength, uint256 bonusBasis)
        public
        onlyPolicy
    {
        uint256 oldBonus = stakeBonusForLength[lockLength];
        stakeBonusForLength[lockLength] = bonusBasis;
        emit UpdateLockBonus(lockLength, oldBonus, bonusBasis);
    }

    /****** VIEW METHODS ******/

    /**
     * @dev calculates the reward value of the amount of the token specified
     * for the lock period provided
     */
    function getRewardvalue(
        address _token,
        uint256 amount,
        StakeLength lockLength
    ) public view returns (uint256) {
        if (address(permittedTokens[_token]) == address(0)) {
            return 0;
        }

        uint256 baseAmount = permittedTokens[_token].getValue(_token, amount);

        uint256 bonus = stakeBonusForLength[lockLength];

        if (bonus != 0) {
            baseAmount += (baseAmount * bonus) / 10000; // calculated from basis points
        }

        return baseAmount;
    }

    /**
     * @dev EIP-1271 support to let external callers check if a given signature
     * is valid for this contract. We do this by checking that the signer of
     * the message has the POLICY_ROLE in the reward token contract
     *
     * For more information, see: https://eips.ethereum.org/EIPS/eip-1271
     */
    function isValidSignature(bytes32 _hash, bytes calldata _signature)
        public
        view
        override
        returns (bytes4)
    {
        if (token.hasRole(token.POLICY_ROLE(), _hash.recover(_signature))) {
            return 0x1626ba7e;
        } else {
            return 0xffffffff;
        }
    }

    /**
     * @dev returns the array of all active stakes for the specified account
     */
    function staked(address account) public view returns (Stake[] memory) {
        // retrieve all of the stake ids for the caller
        bytes32[] memory ids = stakeIds(account);

        // construct the temporary stake information
        Stake[] memory _stakes = new Stake[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
            _stakes[i] = stakeInfo[ids[i]];
        }

        return _stakes;
    }

    /**
     * @dev returns the array of all of the active stake IDs for the specified account
     */
    function stakeIds(address account) public view returns (bytes32[] memory) {
        return _userStakes[account].values();
    }

    /****** STAKING METHODS ******/

    /**
     * @dev generates a stake ID from the provided values
     */
    function _generateStakeId(
        address account,
        address _token,
        uint256 amount
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    account,
                    _token,
                    amount,
                    block.timestamp,
                    block.number
                )
            );
    }

    /**
     * @dev stakes the specified amount of the token for the lock period provided
     * the reward token is instantly released to the address provided in the recipient field
     * and the staked amount is "owned" by the same recipient while allows for
     * further downstream contract handling; however, the caller must provide the
     * token for staking purposes
     */
    function stake(
        IERC20 _token,
        uint256 amount,
        StakeLength lockLength,
        address recipient
    ) public isPermittedToken(address(_token)) returns (bytes32) {
        require(
            _token.allowance(_msgSender(), address(this)) >= amount,
            "Contract not approved to spend LP token"
        );

        // find out the reward token amount that we will pay out
        uint256 rewardAmount = getRewardvalue(
            address(_token),
            amount,
            lockLength
        );

        require(rewardAmount != 0, "Deposited token has no reward token value");

        // transfer the amount of the token to us
        _token.safeTransferFrom(_msgSender(), address(this), amount);

        // generate the stake ID
        bytes32 stakeId = _generateStakeId(
            _msgSender(),
            address(_token),
            amount
        );

        uint256 unlockAt = block.timestamp;

        if (lockLength == StakeLength.WEEK) {
            unlockAt += 7 days;
        } else if (lockLength == StakeLength.MONTH) {
            unlockAt += 30 days;
        } else if (lockLength == StakeLength.QUARTER) {
            unlockAt += 90 days;
        } else if (lockLength == StakeLength.YEAR) {
            unlockAt += 365 days;
        } else {
            revert("Unknown lock length");
        }

        // add the stake ID record
        stakeInfo[stakeId] = Stake({
            owner: recipient,
            token: _token,
            amount: amount,
            rewardAmount: rewardAmount,
            createdAt: block.timestamp,
            unlockAt: unlockAt
        });

        // add the stake ID to the user's tracking
        _userStakes[recipient].add(stakeId);

        // mint the reward token to the caller
        token.mint(recipient, rewardAmount);

        emit Staked(
            recipient,
            address(_token),
            amount,
            rewardAmount,
            block.timestamp,
            unlockAt
        );

        return stakeId;
    }

    /**
     * @dev unstakes (returns) the locked token to the owner specified in the
     * stake as long as the lock period has been completed
     */
    function unstake(bytes32 stakeId) public {
        require(
            stakeInfo[stakeId].unlockAt <= block.timestamp,
            "Stake ID is not unlocked yet"
        );

        // pull the stake info
        Stake memory info = stakeInfo[stakeId];

        // delete the record
        delete stakeInfo[stakeId];

        // delete the stake ID from the user's tracking
        _userStakes[info.owner].remove(stakeId);

        // transfer the tokens back to the user
        info.token.safeTransfer(info.owner, info.amount);

        emit UnStaked(
            info.owner,
            address(info.token),
            info.amount,
            info.rewardAmount,
            info.createdAt,
            info.unlockAt
        );
    }
}
