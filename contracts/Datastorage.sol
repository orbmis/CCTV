// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./LibLinkedList.sol";
import "./Coordinator.sol";
import "./IBase.sol";

/**
 * @title Datastore
 * @dev Datastorage for CFTV platform.  Uses "Inherited Storage" pattern.
 */
contract Datastorage is IBase {

    address router;

    // the native token for this system
    ERC20 token;

    Coordinator coordinator;

    LinkedList.ItemList itemList;

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
