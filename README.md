# CCTV: Community Curated Token Voting

This describes a system to facilitate the curation of NFTs by community voting.

## Introduction

There are a growing number of NFT marketplaces at the moment, and they largely share the same characteristics, in as far as they allow users to browse NFTs, as well as publish and trade NFTs.  Some of these marketplaces have slightly different features, for instance there are those that rank collectibles by rarity of the combination of their traits.  The growth in NFT marketplaces has followed a cambrian explosion in the popularity of NFTs as a medium for publishing art and music etc.  This has resulted in a vast and ever-expanding collection of NFTs on all marketplaces. In the ever growing proliferation of content present across numerous NFT marketplaces, the sheer volume of NFTs presents a significant challenge to user who are looking for high quality artwork.

## Incentivised Voting

To address this challenge, I propose a system of gamified voting as a way to separate the signal from the noise, and to encourage people to take the time to browse published NFTs and vote on them. This would in essence be a community curated collection that promotes the most diligent and dedicated artists, which evolves over time, and which improves the accessibility to inspiring artwork that is published as NFTs.

## Gamification

Anyone can list a published NFT on the platform, "published" being in the sense that it has been published to some public ledger using the erc-721 standard.

Users can browse the listed items and vote any item up or down.  A single address can only vote for a particular item once in an epoch (described below). Votes are initally encrypted, in the form of a "vote-commit".  The vote is only publicly known once the epoch has ended, at which point all the votes are revealed and tallied.

Voting costs a voting fee.  Users must also lock some tokens in escrow for the period of the epoch, which they can retrieve after the epoch expires.  This is referred to as their "voting stake". This means that for every vote, users will spend a voting fee and their voting stake, and will get their token stake back when they reveal their vote.  The purpose of the voting stake is to incentivize users to reveal their vote-commits after the epoch has ended, and not before.

Once an epoch expires, it asummes the status of being the "inactive epoch".  During this period, users can reveal their votes to reclaim their voting stake.  At the next epoch switch, just before the currently inactive epoch becomes the active epoch again, the votes are tallied.  The users that voted for the second-highest-voted-item are rewarded their voting fee back + 0.8 of the voting fee as a reward.  As an example, assume without loss of generality, that a user that spends 10 tokens on a vote, will receive 18 tokens as a reward, if the item they voted for ends up having the second highest number of votes in that epoch.

The owner of the item that was voted for is rewarded 20% of the total voting rewards for that item in that epoch.

## Epoch Transitions

Voting proceeds in epochs, whereby there is an active and an inactive epoch at any one time.  Epochs last for a set amount of time, as parameterized by the system.  An epoch transition occurs when a user submits a transaction to the system after the length of time that an epoch lasts for.  At this stage the the active and inactive switch, whereby the currently active epoch becomes inactive, and will stop accepting votes, and the inactive epoch will become active, and any subsequent votes will be added to that epoch.  At this stage users may reveal the vote-commitments that they submitted in the previous epoch and unlock their voting stake.

Note: in the current design of the system, the transaction that triggers the epoch transition incurs the gas costs of tallying the votes in the epoch that was being made inactive.  During the inactive period, votes that were previously submitted are revealed, and at the subsequent epoch switch, the votes are tallied.  This design means that the user who triggers the epoch switch ends up paying for the gas costs of teh vote tally.  It's possible to make this fairer by using a decentralized oracle to trigger the epoch transition at a set interval.  This would likely involve paying oracle fees from the voting rewards, and as such, requires further consiferation.

## Token Supply and Voting Fee

The total supply of the tokens in the system is fixed.  There is no issuance of new tokens at an point.  This naturally creates a scenario whereby the number of votes for all items being voted on in a given epoch could theoretically exceed the total supply of tokens, thereby preventing anymore voting until the active epoch ends and staked tokens are unlocked.

In order to maintain liveness in the system, the voting fee and voting stake is calculated as a function of the total number of votes cast within the previous epoch.  The fee / stake is calculated as:

![Voting Fee Formula](CCTV/images/cctv_voting_fee_function.png "Voting Fee Formula")

This pricing mechanism ensures that the voting fee + stake will decrease asymptotically as the number of votes increases, thereby eliminating any upper bound on the number of concurrent votes in the system.

![Voting Fee Curve](CCTV/images/cctv_voting-fee-curve.png "Overview of function of calculation of voting fee based on number of votes")

## Sybil Resistance

The rationale for rewarding the second highest item instead of the highest item is as follows: if a malicious actor submits all the votes for the highest-voted-item and the second highest-voted-item, it will cost them more than they gain from rewards.

This prevents malicious actors from voting for their own NFTs in order to receive token rewards.  It would be trivial to write a script to repeatedly vote for your own NFT, by submitting votes from different addresses, and making sure that the number of votes submitted by the script, is greater than the number of votes sent to the smart contract for a given epoch.  Assuming the token reward for each address is more valuable than cost of transaction fees, this would be a clear incentive to cheat the system.

Awarding the votes to the second highest voted item, means that it will always cost a malicious actor more to try to cheat the system than the rewards that they can theoretically obtain.

## Example

Let *x* be the number of votes for the highest voted item

Let *y* be the number of votes for the second highest voted item

In this case, the malicious actor would need to spend *x + y* to guarantee that they have first and second place.  Assuming the rewards are 2y (all the voting fees + 80% voting rewards + 20% item rewards), and with *x > y*, then *2y - (x + y) < 0*.  The reward is a negative value.

## Commit-reveal scheme

The main challenge with the above described system is that all votes are public.  This means that malicious actors can leverage the votes that other users have already placed, to close the gap between the cost of a sybil attack and the rewards obtained.  It also has the disadvantage of incentivising people to vote for items simply because other users have voted for them, and which have a perceived probability of being the item that will receive voting rewards.  This "network effect" will undoubtedly undermine the goal of incentivising people to vote on items based on artistic merit.

To mitigate this problem, a commit-reveal mechanism is implemented, whereby votes are committed to without being made public.  Users submit a commit-hash of a vote which is then locked in the votes for an epoch.

Only after the epoch has expired, can users then reveal their vote, and all the votes for that epoch become public.

This approach mitigates the "herd-mentality" and network-effects and an item receiving votes simply because it already has votes.

There are some edge-case scenarios with this approach that warrant description:

Users need to stake tokens in order to vote.  Every vote requires a certain number of token to be staked, which are then locked for the duration of the epoch. When a user reveals their vote after an epoch expires, their tokens are unlocked.  If users reveal their vote early, then half these staked tokens are burned.  This is to prevent users from colluding by revealing their votes in some side-channel communication to each other.  If they reveal their vote to anyone, then anyone can claim half the locked tokens for themselves (with the other half being burned).  While this mechanism does not guarantee that users will not disclose their voting preference, it does mean that they have no way to prove how they voted without risk of losing some funds.  Burning half the tokens disincentivizes users from revealing the vote on-chain and retrieving the stake themselves.

The pre-image of the commit hash of a vote must be derived from the concatenation of the following data:

* **Epoch number** - the number of the current epoch that is accepting votes
* **Item index** - the index number of the item in the collection
* **Downvote** - this flag is set to true if this vote is a down vote
* **Blinding factor** - a random 256 number used as a blinding factor

This ensures when the vote is revealed, it can only be counted if the epoch number is the same as the epoch that has just expired.  It can also identify votes that were revealed early, and therefore will be slashed.

This structure allows for certain items to incur more negative votes than positive ones, for example, it is feasible that a certain item may have total votes of say, -87, or -23 etc.  To allows for this, we create a range of votes at a certain offset, whereby zero is actually 2<sup>128</sup>.  This is starting level for new items.  Any level below 2<sup>128</sup> is considered a negative number.

## Voter Leaderboard

To aid in gamification, a voter leaderboard maintains a ranking of users who have voted for the most winning items over time.  Every time an epoch is finalized, all users of the winning item will have their ranking incremented.  This should help to incentivized users to vote by providing a reputation based system, where by certain users can build a reputation for being able curate artwork effectively.

Rewards are paid to voters in a certain intervals, as paramterized by the system, (e.g. monthly), the rewards are paid on a pro-rata basis to voters on the leaderboard. The rewards are paid from the amount of tokens in held in the smart contract, that has accumulated from the various voting fees that were not returned to users (i.e. the voting fees for votes for items that did not win the overall vote in an epoch).

This has a dual-purpose: first:  it allows for a fair way to maintain a gamification of the system, helping incentivize people to actualy spend small amounts of tokens on voting, with the chance of winning a reward.  Second: it acts as a way to balance the supply of tokens, by avoiding a scenarion where the total supply of tokens diminishes after every epoch.

![Stock and Flow Diagram](CCTV/images/cctv_stock-and-flow.png "Stock and Flow Diagram")

## Sorting Items by vote (allowing users visibility to highest voted art work)

Voting for items means nothing if other users can't see which items have been voted the highest by the community, or inversely, voted lowest so that they are effectively filtered out.

In order to achieve this, items need to be maintained in a sorted list on-chain.  This requires a sorting algorithm that is efficient and cheap. For this reason, items are stored in a linked-list data structure, and an index is maintained of the number of votes each item has.

## Linked-list

Every item has the following properties:

* Number of votes
* Item to left
* Item to right

There are other properties that are discussed later, but are not relevant to this section, and so are not mentioned here.

The linked-list is maintained by linking every item to it's predecessor and it's successor, by way of the left and right properties.  The "left" property links to the item's predecessor and the right item links to the item's successor.  In this way we can see that every item's "right" property points to an item whose "left" property reciprocally points back to it.

Items are stored in an array, whereby every new item is added to the end of the array.  The right and left properties are set according to the sorting algorithm, which also maintains an second-tier index of votes.

The second-tier index applies a segmented model of ranking based on number of votes.  Each segment is a group of items that have the same number of votes.  When items are added to a segment, they are added to the start (or head) of the section, so that the items near the start of the segment are more recent than the items at the end of the segment.

The item at the "head" of each segment is the most recent addition to the segment.  This item's right property points to the item that was previously at the head of the segment (and is now second in the segment).  The left property of the head item points to the anterior item of the preceding segment (i.e. the segment with the immediately higher number of votes).

### Updating an item's position in the linked list base on votes:

Every time a vote is revealed and subsequently applied to an item, the following algorithm is used to update the linked list with the new position of the item in the list.

The item to which a revealed vote is being applied to is known as the "voted-item" below.

**Preparation:**

* Calculate the new level of votes the voted-item has, by incrementing or decrementing the number of votes that the voted-item currently has, depending on whether the vote is an up-vote or down-vote.

* Using the second-tier index, retrieve the item currently at the head of the section of votes the item is being moved to.  This segment will be the next highest or next lowest segment, depending on whether the vote is an up-vote or down-vote.

**Remove the voted-item from the section that it's currently in:**

* Update the left pointer of the item on voted-item's right, to the item on the voted item's left.
* Update the right pointer of the item on voted-item's left, to the item on voted-item's right.

**Move the voted-item to the head of the target voting segment (the section that corresponds to the number of votes it now has):**

* Set the left pointer of voted-item to the value of the left pointer of the item currently at the head of the section being moved to (which should always be the anterior item of the section with next highest number of votes).
* Set the right pointer of the voted-item to the item at the head of the section being moved to

**Update item that is currently at head of the section being moved to so that it's now the second item in section:**

* Set the left pointer of the item currently at the head of the section being moved to, to the voted-item

**Update the votes index:**

* Update the votes index to set the head of the section that we moved the voted-item to, to the voted-item
* Update the number of votes in the voted-item's record to the new number of votes.

**Record the highest voted item in the epoch, and the second highest, for voting rewards.**

----

Using this method of maintaining a linked-list data structure means that users can retrieve items sorted by votes.  This is done by a function that paginates through the item collection.  Given an item number, and a fixed page size of 10 items, the function starts with the item specified by the item number, and recursively retrieves the item pointed to by the current item's right pointer.  Using this method, a client can traverse the list from any starting point, 10 items at a time.

Note: while is done onchain, the data can also be cached by a centralized service in order to increase performance, which wouldl result in better UX.

![Linked List](CCTV/images/cctv_linked-list.png "Linked List Index")

## Market / Auction

While any NFTs can be listed on the system and can then subsequently be voted on, this does not facilitate any trading or transfer of NFTs through the platform.  To do this, the NFT owner must transfer the NFT to the auction smart contract and start an auction.

NFT owners can deposit and withdraw their NFTs onto the system freely.  Once deposited, the NFT is held in escrow by the market smart contract.  From this point, the NFT owner can start an auction for the NFT, by specifying the NFT's token id, a reserve price (or 0 if no reserve price) and a date and time that the auction will remain open until.  Once an auction has started, the NFT owner can cancel the auction at any time.

While an auction remains open, anyone can place a bid for an item, so long as the bid they are placing satisfies the following criteria:

* The bidder must have enough available (i.e. unlocked) balance on the system to cover the bid.
* The bid is higher than the previously highest bid if any, and is higher than the reserve price.

Once these two criteria are met, the bid is placed, and recorded along with all other bids placed for the auction item.

Once the auction closes, anyone is free to complete the auction and execute settlement.  This will result in the following actions:

* The NFT is transferred to the bidder who placed the highest bid.
* The tokens that the highest bidder placed in escrow are transferred to the seller.
* All other tokens held in escrow are released to the unsuccessful bidders.
* The auction for the item is reset, allowing a new auction to be created by the item's seller.

If the seller cancels the auction, then all funds that are held in escrow are returned to the bidders.

In order to start an auction, an NFT owner must pay a fee.  This is to prevent spoofing, whereby auctions are created, but then cancelled before they reach their stated close, in order to make it appear that item is more valuable than it is.

When an NFT is sold, a fee goes to the system from the sale of the NFT.  The fee is determined by a system parameter, and the accumulated fee is held in a centralized pool.

## Smart Contract Toplogy

The system is comprised at it's core of a collection of smart contracts, that are organized by domain-driven-design.  The smart contracts involved are described as follows:

**Coordinator.sol**

This contract contains the logic for the core functions, including llisting an item, submitting a vote commit, submitting a vote-reveal, claiming epoch rewards etc.

**Datastorage.sol**

This is the main data storage contract.  The application uses a inherited storage pattern for most of the shared state.  To this end, most contract inherit the Datastorage contract, adn therefore have access to the shared state.  This can faciliate upgrading the smart contracts without affecting state storage.  State storage can be updated by adding a new datastorage contract, which itself inherits the existing datastorage contract.  All other contracts would then inherit from the new "child" datastorage contract.

**ICoordinator.sol**

Interface for the Coordinator contract.  Reduces deployment costs for the market contract, by allowing the Market contract to import the interface instead of the full contract in order to reference functions in the Coordinator contract, when making function calls to it.

**LibLinkedList.sol**

Contains the logic for maintaining the sorted linked list of item votes, i.e. inserting items onto the list, move items up or down the list as it's votes increases / decreases, and pagination logic for retrieving items.

**Market.sol**

Contains the logic that governs the processes of buying and selling items via auctions, i.e. depositing and withdrawing NFTs, starting and cancelling auctions, placing bids, transfer of assets etc.

**Router.sol**

This is the main point of entry to external clients with the system. All external function calls (i.e. from the UI) are sent to the router contract, and the router contract "routes" the calls to the correect destiaton contract. This is achieved using a basic proxy pattern, whereby the method id (i.e. the hash of the function selector for the function being called) is used to lookup the destination contract address in amapping, which stores all the method ids for all functions in all contracts in the system, and which are mapped to the address of the rtespective smart contract.  Once the destination contract address has been established, the router uses *delegatecall* to invoke the function on the destination smart contract.

**Token.sol**

This is the smart contract for the erc20 token that is used for voting fees and voting stakes.
