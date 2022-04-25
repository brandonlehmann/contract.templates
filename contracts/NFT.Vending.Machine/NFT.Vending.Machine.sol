// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../../@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../../@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../../@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "../../@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../../@openzeppelin/contracts/security/Pausable.sol";
import "../Cloneable/Cloneable.sol";
import "../PaymentSplitter/PaymentSplitter.sol";
import "../libraries/Random.sol";

contract NFTVendingMachine is IERC721Receiver, IERC1155Receiver, Cloneable, Pausable, Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using SafeERC20 for IERC20;
    using Random for uint256;

    /****** STRUCTURES ******/

    enum NFTType {
        ERC721,
        ERC1155
    }

    struct Collection {
        NFTType tokenType;
        address tokenContract;
        uint256 mintValue;
    }

    struct Prize {
        NFTType collectionType;
        address collection;
        uint256 tokenId;
        uint256 value;
        address winner;
    }

    /****** EVENTS ******/

    event ERC721Received(address indexed operator, address indexed from, uint256 indexed tokenId, bytes data);
    event ERC1155Received(
        address indexed operator,
        address indexed from,
        uint256 indexed id,
        uint256 value,
        bytes data
    );
    event ERC1155BatchReceived(
        address indexed operator,
        address indexed from,
        uint256[] ids,
        uint256[] values,
        bytes data
    );
    event TokenDeposited(address indexed collection, uint256 indexed tokenId, NFTType indexed tokenType);
    event TokenDrawn(address indexed collection, uint256 indexed tokenId, NFTType indexed tokenType, address winner);
    event PaymentTokenUpdate(address indexed _old, address indexed _new);

    /****** STORAGE CONTAINERS ******/

    IERC20 public PAYMENT_TOKEN;

    IPaymentSplitter private immutable BASE_PAYMENT_SPLITTER;
    address private constant developer = 0xb2D555044CdE0a8A297F082f05ae6B1eFf663784;
    uint256 private constant developerShare = 1;

    mapping(address => bool) public permittedCollections; // by contract address, stores if the collection is permitted
    mapping(address => Collection) private _collections;

    EnumerableMap.AddressToUintMap private _collectionShares; // stores the number of "shares" for funds distribution
    uint256 public totalShares; // holds the total shares in existence
    uint256 public totalValueDeposited; // holds the aggregate value of all deposited tokens

    Collection[] public collections; // holds enumerable collections information
    mapping(address => address) public collectionBeneficiary; // by contract address

    mapping(bytes32 => Prize) public prizes; // by hash, stores the prizes
    EnumerableSet.Bytes32Set private _availablePrizes; // used to store and index of available prizes
    EnumerableSet.Bytes32Set private _allPrizes; // used to store an index of all prizes deposited

    IPaymentSplitter public proceedsReceiver;

    /****** CONSTRUCTOR METHOD ******/

    constructor() {
        BASE_PAYMENT_SPLITTER = new PaymentSplitter();
        BASE_PAYMENT_SPLITTER.initialize();
        BASE_PAYMENT_SPLITTER.transferOwnership(address(0));
        // On construction, ownership is transferred to NULL address
        _transferOwnership(address(0));
    }

    function initialize() public initializer isCloned {
        _transferOwnership(_msgSender());
        _pause();
    }

    /****** PUBLIC VIEW METHODS ******/

    function collectionsCount() public view returns (uint256) {
        return collections.length;
    }

    function collectionShares(address collection) public view returns (uint256) {
        require(_collectionShares.contains(collection), "Collection does not have shares");
        return _collectionShares.get(collection);
    }

    function drawPrice() public view returns (uint256) {
        if (totalShares == 0) {
            return 0;
        }
        return totalValueDeposited / totalShares;
    }

    function prize(uint256 index) public view returns (Prize memory) {
        bytes32 hash = _allPrizes.at(index);
        return prizes[hash];
    }

    function prizeCount() public view returns (uint256) {
        return _availablePrizes.length();
    }

    function prizeCountAll() public view returns (uint256) {
        return _allPrizes.length();
    }

    /****** PUBLIC METHODS ******/

    function draw()
        public
        payable
        whenNotPaused
        returns (
            address collection,
            uint256 tokenId,
            NFTType tokenType
        )
    {
        uint256 count = prizeCount();
        require(count != 0, "Potluck complete!");
        uint256 price = drawPrice();

        if (address(PAYMENT_TOKEN) == address(0)) {
            require(msg.value == price, "Caller supplied incorrect amount");

            // send the funds to the payment splitter
            (bool sent, ) = address(proceedsReceiver).call{ value: price }("");
            require(sent, "Could not forward funds to receiver");
            // distribute the funds
            proceedsReceiver.releaseAll();
        } else {
            // send the funds to the payment splitter
            PAYMENT_TOKEN.safeTransferFrom(_msgSender(), address(proceedsReceiver), price);
            // distribute the funds
            proceedsReceiver.releaseAll(address(PAYMENT_TOKEN));
        }

        uint256 random = count.randomize(); // RNG within the bounds of the count
        bytes32 prizeHash = _availablePrizes.at(random); // get the prize hash
        _availablePrizes.remove(prizeHash); // remove the prize from the available prizes

        Prize storage _prize = prizes[prizeHash]; // get the prize data
        _prize.winner = _msgSender(); // update the prize winner

        if (_prize.collectionType == NFTType.ERC721) {
            IERC721(_prize.collection).safeTransferFrom(address(this), _msgSender(), _prize.tokenId);
        } else {
            IERC1155(_prize.collection).safeTransferFrom(address(this), _msgSender(), _prize.tokenId, _prize.value, "");
        }

        emit TokenDrawn(_prize.collection, _prize.tokenId, _prize.collectionType, _msgSender());

        return (_prize.collection, _prize.tokenId, _prize.collectionType);
    }

    /****** TOKEN DEPOSIT METHODS ******/

    function depositTokens(address collection, uint256[] memory tokenIds) public whenPaused {
        require(permittedCollections[collection], "Collection not permitted");
        NFTType _type = _collections[collection].tokenType;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            // take ownership of the token
            if (_type == NFTType.ERC721) {
                IERC721(collection).safeTransferFrom(_msgSender(), address(this), tokenId);
            } else {
                IERC1155(collection).safeTransferFrom(_msgSender(), address(this), tokenId, 1, "");
            }

            // compute the hash
            bytes32 hash = keccak256(abi.encodePacked(collection, tokenId, _msgSender()));

            _availablePrizes.add(hash); // add the prize to the available prizes
            _allPrizes.add(hash); // add the prize to the all prizes

            // construct the prize
            prizes[hash] = Prize({
                collectionType: _type,
                collection: collection,
                tokenId: tokenId,
                value: 1,
                winner: address(0)
            });

            // update the shares
            uint256 shares = _collectionShares.get(collection);
            _collectionShares.set(collection, ++shares);

            // increment the total shares
            totalShares++;

            // bump the aggregated mint price
            totalValueDeposited += _collections[collection].mintValue;

            emit TokenDeposited(collection, tokenId, NFTType.ERC721);
        }
    }

    /****** MANAGEMENT METHODS ******/

    function enableCollection(
        address collection,
        NFTType _type,
        uint256 _mintValue,
        address _beneficiary
    ) public onlyOwner whenPaused {
        require(collection != address(0), "Collection cannot be null address");
        require(!permittedCollections[collection], "Collection Already Enabled");
        require(_beneficiary != address(0), "Beneficiary cannot be null address");

        // set the collection share count to 0
        _collectionShares.set(collection, 0);

        // add the beneficiary
        collectionBeneficiary[collection] = _beneficiary;

        // push the collection to the stack
        _collections[collection] = Collection({ tokenType: _type, tokenContract: collection, mintValue: _mintValue });
        collections.push(_collections[collection]);

        // set the collection as "enabled"
        permittedCollections[collection] = true;
    }

    function setPaymentToken(address token) public onlyOwner whenPaused {
        address old = address(PAYMENT_TOKEN);
        PAYMENT_TOKEN = IERC20(token);
        emit PaymentTokenUpdate(old, token);
    }

    function unpause() public onlyOwner whenPaused {
        require(prizeCount() != 0, "No prizes have been deposited");

        // clone the automatic payment splitter (saves gas)
        proceedsReceiver = IPaymentSplitter(BASE_PAYMENT_SPLITTER.clone());
        proceedsReceiver.initialize();
        proceedsReceiver.addPayee(developer, developerShare); // contract developer gets 1 share

        // loop through the collection shares and set them up as payees in the splitter
        for (uint256 i = 0; i < _collectionShares.length(); i++) {
            (address collection, uint256 shares) = _collectionShares.at(i);
            proceedsReceiver.addPayee(collectionBeneficiary[collection], shares);
        }

        proceedsReceiver.transferOwnership(address(0)); // renounce the ownership of the payment splitter

        _unpause(); // unpause the contract, thereby opening up the drawing

        _transferOwnership(address(0)); // transfer the ownership to the null address
    }

    /****** ERC-165 METHOD ******/

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId;
    }

    /****** RECEIVER METHODS ******/

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public override returns (bytes4) {
        require(operator == address(this), "ERC721Holder: Must not transfer to contract directly");

        emit ERC721Received(operator, from, tokenId, data);

        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) public override returns (bytes4) {
        require(operator == address(this), "ERC1155Holder: Must not transfer to contract directly");

        emit ERC1155Received(operator, from, id, value, data);

        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) public override returns (bytes4) {
        require(operator == address(this), "ERC1155Holder: Must not transfer to contract directly");

        emit ERC1155BatchReceived(operator, from, ids, values, data);

        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}
