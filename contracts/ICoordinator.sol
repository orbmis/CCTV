// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IBase.sol";


/**
 * @title ICoordinator
 * @dev Voting for NFTs
 */
interface ICoordinator is IBase {

    /**
     * This is basically the smart contract's constructor.
     * Becuase we are using contracts as modules behind a common router,
     * the constructor will not be run in the context of the router's storage when we deploy
     * a new version of this module / contract. For that reason we emply an "initializer".
     * This can only be run once, and needs to be called manually directly after deployment.
     *
     * NOTE: this contract to send calls to the market contract via the router
     * otherwise we need to update the market contract address in this contract
     * every time we upgrade the market contract and vice-versa.
     * Therefore the value of the "marketContractAddress" should actually be the
     * address of the router contract, which should forward the calls to the market contract.
     *
     * @param tokenAddress The address of the native token of the platform.
     * @param marketContractAddress The address of the market contract (router).
     * @param adminAddress The adress of the admin of the contract.
     */
    function initialize(
        address tokenAddress,
        address marketContractAddress,
        address adminAddress
    ) external;

    /**
     * Add a new node to the "zero votes" section, this can be added to the start,
     * setting the right node to the previously added node that WAS at the start,
     * and updating the left node of the previous node at the start to this node.
     *
     * @param tokenContractAddress The contract address for the NFT being added.
     * @param tokenId The id of the token that is being added.
     * @param tokenUri The metadata URI for the token being added.
     * @param categoryId The category to add this item under.
     */
    function insertItem(
        address tokenContractAddress,
        uint256 tokenId,
        string memory tokenUri,
        uint256 categoryId
    ) external;

    /**
     * Distribute rewards to everyone who voted for the second highest voted item.
     * Note that we require users to claim rewards themselves (they keep track of it themselves).
     *
     * @param epoch The epoch number in which the vote was committed to.
     * @param itemIndex The index of the item that was voted on in the voting commitment.
     * @param downVote Indicates the vote is a downvote, which should be subtracted from the item's total votes.
     * @param blindingFactor The blinding factor used in the pre-image of the commitment.
     */
    function claimEpochReward(
        uint256 epoch,
        uint256 itemIndex,
        bool downVote,
        uint256 blindingFactor
    ) external;

    /**
     * Commits to a vote for a specific item.
     *
     * @param commitment The hash value of the vote commitment.
     */
    function commitVote(bytes32 commitment) external;

    /**
     * Allows a user to reveal a voting commitment that they have previously made.
     *
     * @param epoch The epoch number in which the vote was committed to.
     * @param itemIndex The index of the item that was voted on in the voting commitment.
     * @param downVote Indicates the vote is a downvote, which should be subtracted from the item's total votes.
     * @param blindingFactor The blinding factor used in the pre-image of the commitment.
     */
    function revealCommit(
        uint256 epoch,
        uint256 itemIndex,
        bool downVote,
        uint256 blindingFactor
    ) external;

    /**
     * Accessor function for retrieving the number of items in the collection.
     *
     * @return numberItems The number of items in the collection.
     */
    function getNumberItems() external view returns (uint256 numberItems);

    /**
     * Accessor function for retrieving data for a single item.
     *
     * @param index The index of the item to retrieve the data for.
     * @return The item referenced by the given token id.
     */
    function getItem(uint256 index) external view returns (Item memory);

    /**
     * Retrieves a page of items from a specified page number.
     *
     * @param requestedPageNumber The page number of the page of items to retrieve.
     * @return itemList The requested page of items.
     */
    function getPageFromPageNumber(uint256 requestedPageNumber)
        external
        view
        returns (Item[10] memory itemList);

    /**
     * Retrieves a page of items from the last item that was retrieved.
     * This assumes the user has started at the start of the collection,
     * i.e. the item with most votes, and is working down the list of items
     * one page at a time.  This approach does allow deep-linking into an
     * arbitrary page in the collection, and allows working from first page onwards.
     *
     * @param itemIndex The index of the last item that was retrieved.
     * @return itemList The next page of items.
     */
    function getPageFromItemIndex(uint256 itemIndex)
        external
        view
        returns (Item[10] memory itemList);

    /**
     * Retrieves an item given it's token id.
     *
     * @param tokenId The unique id of the token to retrieve.
     * @return item The item referenced by the given token id.
     */
    function getItemByTokenId(uint256 tokenId)
        external
        view
        returns (Item memory item);

    /**
     * Clears the data for an existing auction. This is done by setting an auction's
     * reserve price and auction close timestamp to zero.
     *
     * @param tokenId The token id of the item to clear the auction for.
     */
    function clearItemAuctionData(uint256 tokenId) external;

    /**
     * Allows users to deposit tokens into the smart contract
     * for use in voting, whereby tokens are locked for remainder of epoch.
     * Tokens are locked when voting, and unlocked when revealing vote.
     *
     * @param amount The amount of tokens to deposit to the smart contract.
     */
    function deposit(uint256 amount) external;

    /**
     * Allows the user to withdraw their available token balance.
     * This considers any amount that the user has locked as being unavailable for withdrawal.
     *
     * @param amount The amount that the user wishes to withdraw from the contract.
     */
    function withdraw(uint256 amount) external;

    /**
     * Returns the balance available to the user. This is the balance of tokens
     * less the balance of any tokens currently locked or staked.
     *
     * @param userAddress The address to query for the available balance.
     * @return available The available balance for the given address.
     */
    function getAvailableBalance(address userAddress)
        external
        view
        returns (uint256 available);

    /**
     * Update the balance or locked balance of a specific user.
     *
     * @param userAddress The address to update the balance of.
     * @param amount The amount to adjust the balance by.
     * @param negativeAdjustment Whether or not the amount should be subtracted instead of added.
     * @param lockedBalance Whether or not this operation should be applied to address's locked balance.
     */
    function updateBalance(
        address userAddress,
        uint256 amount,
        bool negativeAdjustment,
        bool lockedBalance
    ) external;

    /**
     * Updates an existing category or adds a new one.
     *
     * @param categoryId The id of the category to update, or zero to add a new one.
     * @param categoryName The name of the new / updated category.
     */
    function updateCategories(uint256 categoryId, string memory categoryName) external;

    /**
     * Puts an item up for sale. Is initiated by the item owner.
     * This function can only be called by the market contract.
     *
     * @param tokenId The token id of the item to put up for sale.
     * @param salePrice The price to sell the item for.
     */
    function initiateItemSale(uint256 tokenId, uint256 salePrice) external;

    /**
     * Completes the sale of an item that is up for sale by transferring funds to the seller.
     * The transfer of the sale item takes place on the market smart contract.
     * This function can only be called by the market contract.
     *
     * @param tokenId The token id of the item to put up for sale.
     * @param newOwner The address to tokens to the item seller from.
     */
    function completeItemSale(uint256 tokenId, address newOwner) external;
}