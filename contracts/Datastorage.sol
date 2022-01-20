// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Coordinator.sol";

/**
 * @title Datastore
 * @dev Datastorage for CFTV platform.  Uses "Inherited Storage" pattern.
 */
contract Datastorage {

    address router;

    // the native token for this system
    ERC20 token;

    // the address of the market / auction contract
    // only the market contract can call functions to update balances etc.
    address marketContract;

    // the address of the admin that can add / update categories etc.
    address admin;

    /**
     * Stores data for a single NFT.  Comprises the token contract address and token id,
     * as wel ass the Token URI. Note that the tokenURI can be retrieved from the token contract
     * given the token id, but is included here to reduce calls to on-chain contracts.
     * This can be removed in the future.
     */
    struct TokenData {
        address tokenAddress;
        uint256 tokenId;
        string tokenURI;
    }

    /**
     * Stores a single item in the linked list of items.
     * Comprises the total number of votes for the item (upvotes - downvotes),
     * as well as is indices for the items to the left and right of the item.
     */
    struct Item {
        uint256 numberVotes;
        uint256 left;
        uint256 right;
        uint256 categoryId;
        uint256 reservePrice;
        uint256 auctionClose;
        uint256 salePrice;
        TokenData tokendata;
    }

    // epochs switch between primary and seconday, only one can be active at a time
    enum Epoch {
        PRIMARY,
        SECONDARY
    }

    // the epoch that is currently active and collecting voting commitments
    Epoch activeEpoch = Epoch.PRIMARY;

    // records the block height of when the current epoch was activated
    uint256 activeEpochStart;

    // records the current epoch number, which is incremented on every epoch switch.
    uint256 epochNumber;

    // record the top ten highest voted items in teh current epoch
    uint256[10] highestVotedItems;

    // every item is added under a category
    string[] categories;

    // collection of items (NFTS) that have been added to collection
    Item[] public items;

    // maps an item's tokenId to it's index in the collection
    mapping(uint256 => uint256) public itemIndices;

    // balances of users that have deposited to contract and earned rewards
    mapping(address => uint256) public balances;

    // balances of users that have staked on voting commitment and have had tokens locked
    mapping(address => uint256) public balancesLocked;

    // mapping of "number-of-votes", to item at head of the section for items with those number of votes
    mapping(uint256 => uint256) itemVotesIndex;

    // mapping of epoch -> commitment -> user address
    // commitments are stored as a mapping so we can prevent collisions
    // by easily looking up a commitment to determine if it already exists
    // we don't need to enumerate as it's up to users to open their commitments
    mapping(Epoch => mapping(bytes32 => address)) public commitments;

    Coordinator coordinator;

    struct Bid {
        address bidder;
        uint256 bidPrice;
    }

    // tracks the owners of NFTs that are transferred to this contract for auction
    mapping(uint256 => address) public nftOwners;

    // mapping of token id to arra of bids for that token
    mapping(uint256 => Bid[]) public bids;
}
