// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Datastorage.sol";
import "./ICoordinator.sol";
import "./LibLinkedList.sol";

// CCTV - Community Curated Token Voting

// TODO: add support for tags, which aren't stored on-chain but emitted in event logs
// TODO: voting fee, trading fee, should be calculated as a function of supply
// adding an item is free but selling an NFT requires requires tokens (% of sale price), which are burned on sale

// TODO: contracts should not receive NFTs or Tokens to their own addres
// - this will make upgrading more difficult. The NFT's and Tokens should be in their own separate wallet.

// TODO: add initializer instead of constructor
// TODO: how to record the artist name, and the collection name in the item data?

/**
 * @title Coordinator
 * @dev Voting for NFTs
 */
contract Coordinator is Datastorage, ICoordinator {

    using LinkedList for LinkedList.ItemList;

    // attempt was made to commit a hash that was already used
    error CollisionDetected(bytes32 commitHash);

    event ItemAdded(
        address indexed tokenContractAddress,
        uint256 indexed tokenId,
        string tokenUri,
        uint256 itenIndex
    );

    event VoteCast(uint256 indexed itemIndex, bool downVote, LinkedList.Item item);
    event VoteCommitment(address voter, bytes32 commitHash);
    event Deposit(address depositor, uint256 amount);
    event Withdraw(address depositor, uint256 amount);

    event Claim(
        address indexed voter,
        uint256 indexed epoch,
        uint256 indexed itemIndex
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyMarketContract() {
        require(
            msg.sender == marketContract,
            "Only market contract can call this function"
        );
        _;
    }

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
    ) external override {
        bytes32 storagePosition = keccak256("cctv.coordinator.0.0.1");

        bool contractInitialized;

        assembly {
            contractInitialized := sload(storagePosition)
        }

        require(contractInitialized == false, "Contract already initialized");

        token = ERC20(tokenAddress);

        marketContract = marketContractAddress;
        admin = adminAddress;

        // push a null item to start of the array in order that the array is not zero-indexed
        // this is because we want any item that references index 0 to be at the start or end of the collection
        // therefore, index 0 has to be reserved, and can't contain any actual real item.
        itemList.items.push(LinkedList.Item(0, 0, 0, 0, 0, 0, 0, LinkedList.TokenData(address(0), 0, "")));

        // the first category is the default category, which cannot be edited or assigned to an item
        categories.push("default");

        assembly {
            sstore(storagePosition, true)
        }
    }

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
    ) external override {
        // verify the token being added is a valid erc-721 before actually adding it
        // note that the token contract must implement the ERC721Metadata extension
        // ERC721 nftContract = ERC721(tokenContractAddress);
        // string memory metadata = nftContract.tokenURI(tokenId);

        uint256 newItemIndex = itemList.insert(tokenContractAddress, tokenId, tokenUri, categoryId, ADJUSTED_ZERO);

        emit ItemAdded(tokenContractAddress, tokenId, tokenUri, newItemIndex);
    }

    /**
     * Vote for a specific item in the contract's state.
     * This function is called after a vote commitment is being revealed.
     *
     * @param itemIndex The index of the item that is being voted for.
     * @param downVote This flag is set the vote is a downvote, and should be subtracted from the item's total votes.
     */
    function vote(uint256 itemIndex, bool downVote) internal {
        itemList.move(itemIndex, downVote);

        // we need to record to highest voted item in the epoch, and the second highest etc.
        for (uint256 i = 0; i < highestVotedItems.length; i++) {
            if (highestVotedItems[i] >= itemList.items[itemIndex].numberVotes) {
                highestVotedItems[i] = itemList.items[itemIndex].numberVotes;

                break;
            }
        }

        emit VoteCast(itemIndex, downVote, itemList.items[itemIndex]);
    }

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
    ) external override {
        bytes32 commitHash = keccak256(
            abi.encodePacked(epoch, itemIndex, downVote, blindingFactor)
        );

        Epoch inactiveEpoch = activeEpoch == Epoch.PRIMARY
            ? Epoch.SECONDARY
            : Epoch.PRIMARY;

        // checks
        require(
            epoch == epochNumber - 1,
            "Votes can only be revealed for the one directly preceding it"
        );

        require(
            commitments[inactiveEpoch][commitHash] == BURN_ADDRESS,
            "Vote commitment must be revealed before a claim can be made"
        );

        require(
            itemIndex == highestVotedItems[1],
            "Reward can only be claimed for the item that was voted 2nd highest in previous epoch"
        );

        require(downVote == false, "Rewards cannot be claimed for downvoting");

        // effects
        balances[msg.sender] += REWARD_AMOUNT;

        // set the commit hash to the zero address in the mapping
        // this prevents a claim being made for address more then once
        commitments[activeEpoch][commitHash] = address(0);

        // interactions
        token.transfer(msg.sender, REWARD_AMOUNT);

        emit Claim(msg.sender, epoch, itemIndex);
    }

    /**
     * Commits to a vote for a specific item.
     *
     * @param commitment The hash value of the vote commitment.
     */
    function commitVote(bytes32 commitment) external override {
        uint256 balanceAvailable = balances[msg.sender] -
            balancesLocked[msg.sender];

        require(
            balanceAvailable >= STAKE_AMOUNT,
            "Insufficient balance for staking"
        );

        if (block.number > activeEpochStart + EPOCH_LENGTH) {
            // switch to alternate epoch as this one has passed
            activeEpoch = activeEpoch == Epoch.PRIMARY
                ? Epoch.SECONDARY
                : Epoch.PRIMARY;

            // record the current block height as the start of this epoch
            activeEpochStart = block.number;

            // inrement epoch height
            epochNumber++;
        }

        // NB: this will allow a brute force attack, which is why pedersen commitments or similar would be better
        // alternatively we can ensure a 256 blinding factor was used when we open the commitment
        // this would incentivize users to use a collision-resistant blinding factor
        // this would be done automatically by the client / UI
        if (
            commitments[Epoch.PRIMARY][commitment] != address(0) ||
            commitments[Epoch.SECONDARY][commitment] != address(0)
        ) {
            revert CollisionDetected(commitment);
        }

        commitments[activeEpoch][commitment] = msg.sender;

        balancesLocked[msg.sender] += STAKE_AMOUNT;

        emit VoteCommitment(msg.sender, commitment);
    }

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
    ) external override {
        // the epoch number needs to be part of the pre-image,
        // so that votes cannot be opened after 1 epoch has passed
        require(
            (epoch == epochNumber || epoch == epochNumber - 1),
            "Votes can only be revealed for the current epoch or the one directly preceding it"
        );

        bytes32 commitHash = keccak256(
            abi.encodePacked(epoch, itemIndex, downVote, blindingFactor)
        );

        Epoch inactiveEpoch = activeEpoch == Epoch.PRIMARY
            ? Epoch.SECONDARY
            : Epoch.PRIMARY;

        address inactiveEpochCommitment = commitments[inactiveEpoch][
            commitHash
        ];

        address activeEpochCommitment = commitments[activeEpoch][commitHash];

        bool isRevealSuccess = inactiveEpochCommitment != address(0) &&
            inactiveEpochCommitment != BURN_ADDRESS;

        bool hasRevealedEarly = activeEpochCommitment != address(0) &&
            activeEpochCommitment != BURN_ADDRESS;

        if (isRevealSuccess) {
            vote(itemIndex, downVote);

            // we set the address that the commit-hash maps to to the burn address when revealed
            // this prevents the same commitment from being opened repeatedly
            // and also prevents griefing attacks on commitments with known pre-images
            commitments[inactiveEpoch][commitHash] = BURN_ADDRESS;

            // unlock voter's stake
            balancesLocked[msg.sender] -= STAKE_AMOUNT;
        }

        if (hasRevealedEarly) {
            commitments[activeEpoch][commitHash] = BURN_ADDRESS;

            balancesLocked[msg.sender] -= STAKE_AMOUNT;
            balances[msg.sender] -= STAKE_AMOUNT;

            // send half the stake to the revealer to disincentivize revealing vote off-chain
            token.transfer(msg.sender, STAKE_AMOUNT / 2);

            // burn half the stake to incentivize keeping commitment locked until epoch ends
            token.transfer(BURN_ADDRESS, STAKE_AMOUNT / 2);
        }
    }

    /**
     * Accessor function for retrieving the number of items in the collection.
     *
     * @return numberItems The number of items in the collection.
     */
    function getNumberItems() public view override returns (uint256 numberItems) {
        numberItems = itemList.items.length;
    }

    /**
     * Retrieves a page of items from either a specified page number,
     * or starting from the last item that was previously retrieved.
     *
     * This assumes the user has started at the start of the collection,
     * i.e. the item with most votes, and is working down the list of items
     * one page at a time.  This approach does allow deep-linking into an
     * arbitrary page in the collection, and allows working from first page onwards.
     *
     * @param offset The index of the last item that was retrieved.
     * @param countByPageNumber If set, indicate that we should retrieve by page number.
     * @return page The next page of items.
     */
    function getPageFromItemIndex(uint256 offset, bool countByPageNumber)
        external
        view
        returns (LinkedList.Item[10] memory page)
    {
        page = countByPageNumber
            ? itemList.getPageFromPageNumber(offset)
            : itemList.getPageFromItemIndex(offset);
    }

    /**
     * Accessor function for retrieving data for a single item.
     * Retrieves an item given either it's token id or it's index.
     * If no item is found using the supplied value as a token id,
     * then the supplied value is considered to be the item's index.
     *
     * @param id The unique id or index of the token to retrieve.
     * @return item The item referenced by the given token id.
     */
    function getItem(uint256 id)
        public
        view
        returns (LinkedList.Item memory item)
    {
        uint256 itemIndex = itemList.itemIndices[id];

        uint256 index = itemIndex == 0 ? id : itemIndex;

        item = itemList.items[index];
    }

    /**
     * Retrieves an item's data given it's token id.
     * The relevant data is the token's contract address,
     * it's reserver price, and the timestamp for when the auction closes.
     *
     * @param tokenId The unique id of the token to retrieve.
     */
    function getItemMarketData(uint256 tokenId)
        public
        view override
        returns (address, uint256, uint256)
    {
        uint256 itemIndex = itemList.itemIndices[tokenId];

        LinkedList.Item memory item = itemList.items[itemIndex];

        return (item.tokendata.tokenAddress, item.auctionClose, item.reservePrice);
    }

    /**
     * Clears the data for an existing auction. This is done by setting an auction's
     * reserve price and auction close timestamp to zero.
     *
     * @param tokenId The token id of the item to clear the auction for.
     */
    function clearItemAuctionData(uint256 tokenId) external override onlyMarketContract {
        uint256 itemIndex = itemList.itemIndices[tokenId];

        itemList.items[itemIndex].reservePrice = 0;
        itemList.items[itemIndex].auctionClose = 0;
    }

    /**
     * Allows users to deposit tokens into the smart contract
     * for use in voting, whereby tokens are locked for remainder of epoch.
     * Tokens are locked when voting, and unlocked when revealing vote.
     *
     * @param amount The amount of tokens to deposit to the smart contract.
     */
    function deposit(uint256 amount) external override {
        token.transferFrom(msg.sender, address(this), amount);

        balances[msg.sender] += amount;

        emit Deposit(msg.sender, amount);
    }

    /**
     * Allows the user to withdraw their available token balance.
     * This considers any amount that the user has locked as being unavailable for withdrawal.
     *
     * @param amount The amount that the user wishes to withdraw from the contract.
     */
    function withdraw(uint256 amount) external override {
        // subtract any tokens that are curently locked from the amount available to withdraw
        uint256 balanceAvailable = balances[msg.sender] -
            balancesLocked[msg.sender];

        // checks
        require(balanceAvailable >= amount, "Insufficient Balance");

        // effects
        balances[msg.sender] -= amount;

        // interactions
        token.transfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    /**
     * Returns the balance available to the user. This is the balance of tokens
     * less the balance of any tokens currently locked or staked.
     *
     * @param userAddress The address to query for the available balance.
     * @return available The available balance for the given address.
     */
    function getAvailableBalance(address userAddress)
        public
        view override
        returns (uint256 available)
    {
        available = balances[userAddress] - balancesLocked[userAddress];
    }

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
    ) public override onlyMarketContract {
        require(
            msg.sender == marketContract,
            "Can only be called be market contract"
        );

        uint256 balance = lockedBalance
            ? balancesLocked[userAddress]
            : balances[userAddress];

        if (lockedBalance) {
            balancesLocked[userAddress] = negativeAdjustment
                ? balance - amount
                : balance + amount;
        } else {
            balances[userAddress] = negativeAdjustment
                ? balance - amount
                : balance + amount;
        }
    }

    /**
     * Updates an existing category or adds a new one.
     *
     * @param categoryId The id of the category to update, or zero to add a new one.
     * @param categoryName The name of the new / updated category.
     */
    function updateCategories(uint256 categoryId, string memory categoryName)
        external override
        onlyAdmin
    {
        if (categoryId > 0) {
            categories[categoryId] = categoryName;
        } else {
            categories.push(categoryName);
        }
    }

    /**
     * Puts an item up for sale. Is initiated by the item owner.
     * This function can only be called by the market contract.
     *
     * @param tokenId The token id of the item to put up for sale.
     * @param salePrice The price to sell the item for.
     */
    function initiateItemSale(uint256 tokenId, uint256 salePrice)
        external override
        onlyMarketContract
    {
        uint256 itemIndex = itemList.itemIndices[tokenId];

        itemList.items[itemIndex].salePrice = salePrice;
    }

    /**
     * Completes the sale of an item that is up for sale by transferring funds to the seller.
     * The transfer of the sale item takes place on the market smart contract.
     * This function can only be called by the market contract.
     *
     * @param tokenId The token id of the item to put up for sale.
     * @param newOwner The address to tokens to the item seller from.
     * @return result True if everything went well.
     */
    function completeItemSale(uint256 tokenId, address newOwner)
        external override
        onlyMarketContract
        returns (bool result)
    {
        uint256 itemIndex = itemList.itemIndices[tokenId];

        uint256 salePrice = itemList.items[itemIndex].salePrice;

        // if sale price is zero, then the ite is not for sale
        require(itemList.items[itemIndex].salePrice > 0, "Item not for sale");

        require(
            balances[newOwner] >= salePrice,
            "Insufficient balance to complete sale"
        );

        balances[newOwner] -= salePrice;

        itemList.items[itemIndex].salePrice = 0;

        result = true;
    }
}