// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "hardhat/console.sol";

/**
 * @title LinkedList
 * @dev Library for maintaining sorted linked lists.
 */
library LinkedList {

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

    struct ItemList {
        // collection of items (NFTS) that have been added to collection
        Item[] items;

        // maps an item's tokenId to it's index in the collection
        mapping(uint256 => uint256) itemIndices;

        // mapping of "number-of-votes", to item at head of the section for items with those number of votes
        mapping(uint256 => uint256) itemVotesIndex;
    }

    /**
     * Add a new node to the "zero votes" section, this can be added to the start,
     * setting the right node to the previously added node that WAS at the start,
     * and updating the left node of the previous node at the start to this node.
     *
     * @param itemList The collection to insert an item into.
     * @param tokenContractAddress The contract address for the NFT being added.
     * @param tokenId The id of the token that is being added.
     * @param tokenUri The metadata URI for the token being added.
     * @param categoryId The category to add this item under.
     */
    function insert(
        ItemList storage itemList,
        address tokenContractAddress,
        uint256 tokenId,
        string memory tokenUri,
        uint256 categoryId,
        uint256 adjustZero
    ) external returns (uint256) {
        // collate metadata
        TokenData memory tokenData = TokenData(
            tokenContractAddress,
            tokenId,
            tokenUri
        );

        require(categoryId > 0, "Category id must be greater than zero");

        // create new item
        Item memory item = Item(
            adjustZero, // numberVotes
            0, // left
            0, // right
            categoryId,
            0, // reservePrice
            0, // auctionClose
            0, // salePrice
            tokenData
        );

        // add new token to collection
        itemList.items.push(item);

        // get the current item's index
        uint256 newItemIndex = itemList.items.length - 1;

        // get item that is currently at the head of the zero-votes section
        uint256 currentZeroVotesHead = itemList.itemVotesIndex[0];

        // set the left value of the new item to the item that WAS at the head of the zero votes section
        itemList.items[currentZeroVotesHead].left = newItemIndex;

        // set the right value of the previous HEAD item to the index of the new item
        itemList.items[newItemIndex].right = currentZeroVotesHead;

        // update the index so that the head of the zero votes section points to the new item's index
        itemList.itemVotesIndex[0] = newItemIndex;

        // add the item index to the itemIndices mapping under the item's token id
        itemList.itemIndices[tokenId] = newItemIndex;

        return newItemIndex;
    }

    /**
     * Vote for a specific item in the contract's state.
     * This function is called after a vote commitment is being revealed.
     *
     * @param itemList The collection in which to move an item.
     * @param itemIndex The index of the item that is being voted for.
     * @param downVote This flag is set the vote is a downvote, and should be subtracted from the item's total votes.
     */
    function move(ItemList storage itemList, uint256 itemIndex, bool downVote) internal {
        // get the current number of votes that the specified item has at the moment
        uint256 currentNumberVotes = itemList.items[itemIndex].numberVotes;

        // calculate the new level of votes the item has
        uint256 newNumberVotes = downVote == true
            ? currentNumberVotes - 1
            : currentNumberVotes + 1;

        // get the item that's at the head of the section of votes of the new number of votes
        uint256 newVotesSectionHeadItem = itemList.itemVotesIndex[newNumberVotes];

        // update the left pointer of the item on the current item's right to the item on the current item's left
        itemList.items[itemList.items[itemIndex].right].left = itemList.items[itemIndex].left;

        // update the right pointer of the item on the current item's left to the item on the current item's right
        itemList.items[itemList.items[itemIndex].left].right = itemList.items[itemIndex].right;

        // set the left pointer of the current item to the left pointer of the previous section head
        itemList.items[itemIndex].left = itemList.items[newVotesSectionHeadItem].left;

        // set the right pointer of the current item to the previous head of the votes section
        itemList.items[itemIndex].right = newVotesSectionHeadItem;

        // set the left pointer of the previous head to the current item
        itemList.items[newVotesSectionHeadItem].left = itemIndex;

        // set the head of the new votes section to the current item in the voting index
        itemList.itemVotesIndex[newNumberVotes] = itemIndex;

        // adjust the number of votes accordingly
        itemList.items[itemIndex].numberVotes = newNumberVotes;
    }

    /**
     * Retrieves a page of items from a specified page number.
     *
     * @param itemList The collection in which to move an item.
     * @param requestedPageNumber The page number of the page of items to retrieve.
     * @return page The requested page of items.
     */
    function getPageFromPageNumber(ItemList storage itemList, uint256 requestedPageNumber)
        external
        view
        returns (Item[10] memory page)
    {
        bool pageComplete = false;

        uint256 n = 0;
        uint256 i = 1;
        uint256 p = 1;
        uint256 currentPageNumber = 1;
        uint256 nextItemIndex = 0;

        while (!pageComplete) {
            Item memory currentItem = itemList.items[i];
            nextItemIndex = currentItem.right;

            i++;
            p++;

            if (currentPageNumber > requestedPageNumber) {
                break;
            }

            if (currentPageNumber == requestedPageNumber) {
                page[n] = currentItem;
                n++;
            }

            if (nextItemIndex == 0) {
                break;
            }

            if (p == 10) {
                currentPageNumber++;
                p = 1;
            }
        }
    }

    /**
     * Retrieves a page of items from the last item that was retrieved.
     * This assumes the user has started at the start of the collection,
     * i.e. the item with most votes, and is working down the list of items
     * one page at a time.  This approach does allow deep-linking into an
     * arbitrary page in the collection, and allows working from first page onwards.
     *
     * @param itemList The collection in which to move an item.
     * @param itemIndex The index of the last item that was retrieved.
     * @return page The next page of items.
     */
    function getPageFromItemIndex(ItemList storage itemList, uint256 itemIndex)
        external
        view
        returns (Item[10] memory page)
    {
        page[0] = itemList.items[itemIndex + 1];

        for (uint256 i = 1; i < 10; i++) {
            // in case we reach the end of the collection
            if (page[i - 1].right == 0) {
                break;
            }

            page[i] = itemList.items[itemList.items[i - 1].right];
        }
    }
}
