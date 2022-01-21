// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "hardhat/console.sol";

/**
 * @title Coordinator
 * @dev Voting for NFTs
 */
interface IBase {

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

    struct Bid {
        address bidder;
        uint256 bidPrice;
    }

    // epochs switch between primary and seconday, only one can be active at a time
    enum Epoch {
        PRIMARY,
        SECONDARY
    }
}