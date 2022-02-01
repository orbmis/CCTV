// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./LibLinkedList.sol";
import "./Coordinator.sol";

/**
 * @title Datastore
 * @dev Datastorage for CFTV platform.  Uses "Inherited Storage" pattern.
 */
contract Datastorage {

    address router;

    // the native token for this system
    ERC20 token;

    Coordinator coordinator;

    LinkedList.ItemList itemList;

    // to disambiguate from default initialization value of address types, i.e. address(0)
    address BURN_ADDRESS =
        address(0x000000000000000000000000000000000000dEaD);

    // to allow for negative numbers of votes, we create a range of -32768 to +32768
    // to do this we take 2*16, or 65536, and set zero to the mid-point, i.e. 32768
    // this means that 32760 is actually -8
    uint256 ADJUSTED_ZERO = 2**128;

    // currently users need to stake 1 token to vote
    uint256 STAKE_AMOUNT = 10**18;

    // currently users are rewarded 1 token for voting
    uint256 REWARD_AMOUNT = 10**18;

    // an epoch should be around a week (assuming block times are ~ 15 secs.)
    uint32 EPOCH_LENGTH = 15 * 4 * 60 * 24 * 7;

    struct Bid {
        address bidder;
        uint256 bidPrice;
    }

    // epochs switch between primary and seconday, only one can be active at a time
    enum Epoch {
        PRIMARY,
        SECONDARY
    }

    // the address of the market / auction contract
    // only the market contract can call functions to update balances etc.
    address marketContract;

    // the address of the admin that can add / update categories etc.
    address admin;

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

    // balances of users that have deposited to contract and earned rewards
    mapping(address => uint256) public balances;

    // balances of users that have staked on voting commitment and have had tokens locked
    mapping(address => uint256) public balancesLocked;

    // mapping of epoch -> commitment -> user address
    // commitments are stored as a mapping so we can prevent collisions
    // by easily looking up a commitment to determine if it already exists
    // we don't need to enumerate as it's up to users to open their commitments
    mapping(Epoch => mapping(bytes32 => address)) public commitments;

    // tracks the owners of NFTs that are transferred to this contract for auction
    mapping(uint256 => address) public nftOwners;

    // mapping of token id to arra of bids for that token
    mapping(uint256 => Bid[]) public bids;
}
