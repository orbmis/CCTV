// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./Coordinator.sol";
import "./Datastorage.sol";

/**
 * @title Market
 * @dev Buying and Selling NFTs
 */
contract Market is IERC721Receiver, Datastorage {

    event NftDeposited(
        address indexed owner,
        address indexed tokenContractAddress,
        uint256 tokenId
    );

    event NftWithdrawn(
        address indexed owner,
        address indexed tokenContractAddress,
        uint256 tokenId
    );

    event AuctionStarted(
        address tokenContract,
        uint256 tokenId,
        uint256 reservePrice,
        uint256 auctionClose
    );

    event AuctionCancelled(address tokenContract, uint256 tokenId);

    event BidPlaced(
        address indexed bidder,
        uint256 indexed tokenId,
        uint256 bidPrice,
        uint256 auctionClose
    );

    event ERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes data
    );

    constructor(address coordinatorContractAddress) {
        coordinator = Coordinator(coordinatorContractAddress);
    }

    /**
     * Handles the receipt of an NFT. The ERC721 smart contract calls this function on the recipient
     * after a `transfer`. This function MAY throw to revert and reject the transfer.
     * Return of other than the magic value MUST result in the transaction being reverted.
     *
     * Note: the contract address is always the message sender.
     *
     * @param operator The address which called `safeTransferFrom` function
     * @param from The address which previously owned the token
     * @param tokenId The NFT identifier which is being transferred
     * @param data Additional data with no specified format
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public virtual override returns (bytes4) {
        // bytes4(keccak256("onERC721Received(address,uint256,bytes)"))
        emit ERC721Received(operator, from, tokenId, data);

        return this.onERC721Received.selector; // 0x150b7a02
    }

    /**
     * Allows users to deposit an NFT into the contract for voting / selling etc.
     *
     * @param tokenContractAddress The address of the NFT smart contract.
     * @param tokenId The unique identifier for the NFT.
     */
    function depositNFT(address tokenContractAddress, uint256 tokenId)
        external
    {
        // checks

        // effects
        nftOwners[tokenId] = msg.sender;

        // interactions
        ERC721(tokenContractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );

        emit NftDeposited(msg.sender, tokenContractAddress, tokenId);
    }

    /**
     * Allows users to withdraw an NFT from the contract.
     *
     * @param tokenContractAddress The address of the NFT smart contract.
     * @param tokenId The unique identifier for the NFT.
     */
    function withdrawNFT(address tokenContractAddress, uint256 tokenId)
        external
    {
        Item memory item = coordinator.getItemByTokenId(tokenId);

        uint256 auctionClose = item.auctionClose;

        bool auctionInProgress = auctionClose > 0 &&
            auctionClose < block.timestamp;

        require(!auctionInProgress, "Existing auction currently in progress");

        require(
            nftOwners[tokenId] == msg.sender,
            "Cannot withdraw NFT you don't own"
        );

        // TODO: cannot withdraw if there is a current auction in progress
        // or having completed and is waiting to be claimed by highest bidder

        // effects
        nftOwners[tokenId] = address(0);

        // interactions
        ERC721(tokenContractAddress).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );

        emit NftWithdrawn(msg.sender, tokenContractAddress, tokenId);
    }

    /**
     * Starts an auction for an item in the collection.
     * Only the current owner of the item can start an auction.
     *
     * @param tokenId The nft's unique token id.
     * @param reservePrice The minimum price at which bids are accepted.
     * @param auctionClose The timestamp at which the auction will end.
     */
    function startAuction(
        uint256 tokenId,
        uint256 reservePrice,
        uint256 auctionClose
    ) external {
        Item memory item = coordinator.getItemByTokenId(tokenId);

        address tokenContract = item.tokendata.tokenAddress;
        uint256 currentClose = item.auctionClose;

        require(
            auctionClose > block.timestamp,
            "Auction close must be in the future"
        );

        require(
            currentClose > 0 && currentClose < block.timestamp,
            "Existing auction currently in progress"
        );

        require(
            nftOwners[tokenId] == msg.sender,
            "Only token owners can start an auction for the token"
        );

        coordinator.clearItemAuctionData(tokenId);

        emit AuctionStarted(tokenContract, tokenId, reservePrice, auctionClose);
    }

    /**
     * Cancel's an auction that's currently in progress.
     * Only the current owner of the item being auctioned can cancel the auction,
     * and they can't cancel it after the auction has ended.
     *
     * @param tokenId The nft's unique token id.
     */
    function cancelAuction(uint256 tokenId) external {
        Item memory item = coordinator.getItemByTokenId(tokenId);

        address tokenContract = item.tokendata.tokenAddress;

        require(
            nftOwners[tokenId] == msg.sender,
            "Only token owners can cancel an auction"
        );

        require(
            item.auctionClose > block.timestamp,
            "Cannot cancel an auction that has already ended"
        );

        coordinator.clearItemAuctionData(tokenId);

        // unlock all locked bids curently held in escrow
        for (uint256 i = 0; i < bids[tokenId].length; i++) {
            coordinator.updateBalance(
                bids[tokenId][i].bidder,
                bids[tokenId][i].bidPrice,
                true,
                true
            );
            // balancesLocked[bids[tokenId][i].bidder] -= bids[tokenId][i].bidPrice;
        }

        // clear all auction bids for this item
        delete bids[tokenId];

        emit AuctionCancelled(tokenContract, tokenId);
    }

    /**
     * Allows a user to place a bid on an item currently being auctioned.
     *
     * @param tokenId The nft's unique token id.
     * @param bidPrice The price the user is willing to bid for the item.
     */
    function placeBid(uint256 tokenId, uint256 bidPrice) external {
        Item memory item = coordinator.getItemByTokenId(tokenId);

        // bidder must have enough balance to cover bid
        uint256 available = coordinator.getAvailableBalance(msg.sender);

        require(available >= bidPrice, "Insufficient balance to place bid");

        // bid must be higher than auction reserve price
        uint256 reservePrice = item.reservePrice;

        require(
            bidPrice > reservePrice,
            "Bid must be greater than reserve price"
        );

        // auction must be open
        require(
            item.auctionClose > block.timestamp,
            "Auction has closed for this item"
        );

        // new bid will only be accepted if higher than the current highest bid
        require(
            bidPrice >= bids[tokenId][bids[tokenId].length - 1].bidPrice,
            "Bid must be higher then current highest bid"
        );

        // bid will be locked in escrow until auction closes
        coordinator.updateBalance(msg.sender, bidPrice, false, true);
        // balancesLocked[msg.sender] += bidPrice;

        // record new bid against item
        bids[tokenId].push(Bid(msg.sender, bidPrice));

        emit BidPlaced(msg.sender, tokenId, bidPrice, item.auctionClose);
    }

    /**
     * Cancels an existing bid for an item that is currently up for auction.
     *
     * @param tokenId The nft's unique token id.
     * @param bidPrice The price the user has bidded for the item.
     */
    function cancelBid(uint256 tokenId, uint256 bidPrice) external {
        Item memory item = coordinator.getItemByTokenId(tokenId);

        Bid memory bid;

        uint256 bidIndex;

        // enumerate through bids to find the one that matches bidPrice and msg.sender
        for (uint256 i = 0; i < bids[tokenId].length; i++) {
            if (
                bids[tokenId][i].bidPrice == bidPrice &&
                bids[tokenId][i].bidder == msg.sender
            ) {
                bid = bids[tokenId][i];
                bidIndex = i;
            }
        }

        // make sure bid exists
        require(bid.bidder != address(0), "No matching bid found");

        // make sure that auction is not closed
        require(
            item.auctionClose > block.timestamp,
            "Auction has closed for this item"
        );

        // unlock funds for bidder
        coordinator.updateBalance(msg.sender, bidPrice, true, true);
        // balancesLocked[msg.sender] -= bidPrice;

        // remove bid
        delete bids[tokenId][bidIndex];
    }

    /**
     * Completes an auction that has closed by transferred funds fro mthe highest bidder
     * to the seller, and transfer the auction item to the winning bidder.
     * Can be called by bidder of winning bid OR item seller (or anyone really).
     *
     * @param tokenId The nft's unique token id.
     */
    function completeAuction(uint256 tokenId) external {
        Item memory item = coordinator.getItemByTokenId(tokenId);

        address bidder = bids[tokenId][bids[tokenId].length - 1].bidder;
        uint256 bidPrice = bids[tokenId][bids[tokenId].length - 1].bidPrice;

        // auction has closed
        require(
            item.auctionClose < block.timestamp,
            "Auction is still open for this item"
        );

        // NFT was not already claimed by succesful bidder
        require(
            nftOwners[tokenId] != bidder,
            "NFT is already owned by this address"
        );

        // reset the item's auction parameters
        coordinator.clearItemAuctionData(tokenId);

        // clear all auction bids for this item
        delete bids[tokenId];

        // transfer tokens to item seller from bidder
        coordinator.updateBalance(bidder, bidPrice, true, true);
        coordinator.updateBalance(bidder, bidPrice, true, false);
        coordinator.updateBalance(nftOwners[tokenId], bidPrice, false, false);
        // balancesLocked[bidder] -= bidPrice;
        // balances[bidder] -= bidPrice;
        // balances[nftOwners[tokenId]] += bidPrice;

        // mark the succesful bidder as the new item owner
        nftOwners[tokenId] = bidder;
    }

    /**
     * Puts an item up for sale. Is initiated by the item owner.
     *
     * @param tokenId The token id of the item to put up for sale.
     * @param salePrice The price to sell the item for.
     */
    function sellItem(uint256 tokenId, uint256 salePrice) external {
        coordinator.initiateItemSale(tokenId, salePrice);
    }

    /**
     * Buys an item that is up for sale. The new item is transferred to the buyer
     * and the sale price amount of tokens are transferred to the seller.
     *
     * @param tokenId The token id of the item to put up for sale.
     */
    function buyItem(uint256 tokenId) external {
        bool result = coordinator.completeItemSale(tokenId, msg.sender);

        if (result) {
            nftOwners[tokenId] = msg.sender;
        }
    }
}
