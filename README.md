# CCTV: Community Curated Token Voting

This describes a system to facilitate the curation of NFTs by community / user voting.


## Introduction


There are a number of NFT marketplaces on the web at the moment, and they largely share the same characteristics, in as far as they allow users to brows NFTs, as well as publish and trade NFTs.  Some of these marketplaces have slightly different features, for instance there are those that rank collectibles by rarity of the combination of their traits.  That being said, most NFT marketplaces currently suffer from the same drawbacks from a user’s perspective: the challenge of separating signal from noise.

There has been a huge explosion in the popularity of NFTs as a medium for publishing art work in particular.  This has resulted in a vast and ever-expanding collection of NFTs on all marketplaces. However, not all NFTs are created equal, and the quality of production and inherent aesthetic value varies greatly.  There exists no way to filter out the noise, (i.e. the huge amount of hastily produced, low quality NFT art-work), from the truly inspiring high quality art-work that exists within the noise.  The only metrics currently available for ranking individual NFTs is price, but this has it’s drawbacks as well.  Is an piece of art a great piece of art if it hasn’t sold for a high price?  Surely it must be discovered before someone can value it?


## Incentivised Voting:


To address this challenge, I propose a system of incentivised voting as a way to separate the signal from the noise, and to encourage people to take the time to browse published NFTs and vote on them, in order to create a community curated collection that promotes the most diligent and talented artists, and which evolves over time.  This collection would help to make NFTs more accessible to people, making it easier to discover and appreciate great art.


## Gamification:


Anyone can list a published NFT to the platform, published being in the sense that it has been published to a public ledger using the erc-721 standard.

Users can browse the listed items and vote any item up or down.  A single address can only vote for a particular item once in an epoch (described below). Voting costs a voting fee (e.g. 1 token).  Users must also lock some tokens in escrow for the period of the epoch (e.g. 1 token), which they can retrieve after the epoch expires.  This is referred to as their “voting stake”. This means that for every vote, users will spend 2 tokens, and will get 1 token back when they reveal their vote.

Epochs last roughly one week.  Once an epoch expires, the addresses that voted for the second highest-voted-item are rewarded their voting fee back + 0.8 of the voting fee as a reward.

The owner of the item that was voted for is rewarded 20% of the total voting rewards for that item in that epoch.

## Sybil Resistance:

The rationale for rewarding the second highest item instead of the highest item is this: if a malicious actor submits all the votes for the hishest-voted-item and the second highest-voted-item, it will cost them more than they gain from rewards.

This prevents malicious actors from voting for their own NFTs in order to receive token rewards.  It would be trivial to write a script to repeatedly vote for your own NFT, by submitting votes from different addresses, and making sure that the number of votes submitted by the script, is greater than the number of votes sent to the smart contract for a given epoch.  Assuming the token reward for each address is more valuable than cost of transaction fees, this would be a clear incentive to cheat the system.

Awarding the votes to the second highest voted item, means that it will always cost a malicious actor more to try to cheat the system than the rewards that they can theoretically obtain.


## Example:


Let x be the number of votes for the highest voted item
Let y be the number of votes for the second highest voted item

In this case, the malicious actor would need to spend x + y to guarantee that they have first and second place.  Assuming the rewards are 2y (all the voting fees + 80% voting rewards + 20% item rewards), and with x > y, then 2y - (x + y) < 0.  The reward is a negative value.


## Commit-reveal scheme:


The main challenge with the above described system is that all votes are public.  This means that malicious actors can leverage the votes that other users have already placed to close the gap between the cost of a sybil attack, and the rewards obtained.  It also has the disadvantage of incentivising people to vote for items simply because other users have voted for them, and which have a perceived probability of being the item that will receive voting rewards.  This “network effect” will undoubtedly undermine the goal of incentivising people to vote on items based on artistic merit.

To mitigate this problem, a commit-reveal mechanism is implemented, whereby votes are committed to without being made public.  Users submit a commit-hash of a vote which is then locked in the votes for an epoch.

Only after the epoch has expired, can users then reveal their vote, and all the votes for that epoch become public.

This approach mitigates the “herd-mentality” and network-effects and an item receiving votes simply because it already has votes.

There are some edge-case scenarios with this approach that warrant description:

Users need to stake tokens in order to vote.  Every vote requires 1 token to be staked, which are then locked for the duration of the epoch. When a user reveals their vote after an epoch expires their tokens are unlocked.  If users reveal their vote early, then half these staked tokens are burned.  This is to prevent users from colluding by revealing their votes in some side-channel communication to each other.  If they reveal their vote to anyone, then anyone can claim half the locked tokens for themselves (with the other half being burned).  Burning half the tokens disincentivizes users from revealing the vote on-chain and retrieving the stake themselves.

The pre-image of the commit hash of a vote must be derived from the concatenation of the following data:

* **Epoch number** - the number of the current epoch that is accepting votes
* **Item index** - the index number of the item in the collection
* **Downvote** - this flag is set to true if this vote is a down vote
* **Blinding factor** - a random 256 number used as a blinding factor

This ensures when the vote is revealed, is can only be counted if the epoch number if for the epoch that has just expired.  It can also identify votes that were revealed early, and therefore will be slashed.

Number of votes - offset to allow negative numbers!!!

## Sorting Items by vote - allowing users visibility to highest voted art work:


Voting for items means nothing if other users can’t see which items have been votes highest by the community, or inversely, voted lowest so that they are effectively filtered out.

In order to achieve this, items need to be maintained in a sorted list on-chain.  This requires a sorting algorithm that is efficient and cheap. For this reason, items are stored in a linked-list data structure, and an index is maintained of the number of votes each item has.

## Linked-list:


Every item has the following properties:

* Number of votes
* Item to left
* Item to right

There are other properties that are discussed later, but are not relevant to this section, and so are not mentioned here.

The linked-list is maintained by linking every item to it’s predecessor and it’s successor by way of the left and right properties.  The “left” property links to the item’s predecessor and the right item links to the item’s successor.  In this way we can see that every item’s “right” property points to an item whose “left” property reciprocally points back to it.

Items are stored in an array, whereby every new item is added to the end of the array.  The right and left properties are set according to the sorting algorithm, which involves an index of votes.

The index applies a segmented model of ranking based on votes.  Each segment is a group of items that have the same number of votes.  The item at the “head” of the section is the item that was added to the section last.  This item’s right property points to the item that was previously at the head of the section (and is now second in the section).  The left property points to the anterior item of the preceding section (i.e. the section with the next highest amount of votes).

Every time a vote is revealed and subsequently applied to an item, the following algorithm is used to update the linked list with the new position of the item in the list.

The item to which a revealed vote is being applied to is known as the “voted-item” below.

* Calculate the new level of votes the voted-item has by incrementing or decrementing the number of votes that the voted-item currently has, depending on whether the vote is an up-vote or down-vote.

* Retrieve the item currently at the head of the section of votes the item is being moved.  This section will be the next highest or next lowest section depending on whether the vote is an up-vote or down-vote.  This can be retrieved from the votes index.

Remove the voted-item from the section that it’s currently in:

* Update the left pointer of the item on voted-item’s right, to the item on the voted item's left.
* Update the right pointer of the item on voted-item’s left, to the item on voted-item’s right.

Move the voted-item to the head of the new voting section (the section that corresponds to the number of votes it now has):

* Set the left pointer of voted-item to the value of the left pointer of the item currently at the head of the section being moved to (which should always be the anterior item of the section with next highest number of votes).
* Set the right pointer of the voted-item to the item at the head of the section being moved to

Update item that is currently at head of the section being moved to so that it’s now the second item in section:

* Set the left pointer of the item currently at the head of the section being moved to, to the voted-item

Update the votes index:

* Update the votes index to set the head of the section that we moved the voted-item to, to the voted-item
* Update the number of votes in the voted-item’s record to the new number of votes.
Record the highest voted item in the epoch, and the second highest, for voting rewards.



Using this method of maintain a linked-list data structure means that users can retrieve items sorted by votes.  This is done by a function that paginates through the list.  With a fixed page size of 10 items, the function takes the item that is at the head of the section with the highest number of votes, and traverses the linked-list by aggregates the page of recursively retrieving the item that is pointed to by the current item’s “right” property.

## Market / Auction

While any NFTs can be listed on the system and can then henceforth be voted on, this does not facilitate any trading or transfer of NFTs through the platform.  To do this, the NFT owner must transfer the NFT to the auction smart contract and start an auction.

NFT owners and can deposit and withdraw their NFTs onto the system freely.  Once deposited, the NFT is held in escrow by the market smart contract.  From this point, the NFT owner can start an auction for the NFT, by specify the NFT's token id, a reserve price (or 0 if no reserve price) and a date and time that the auction will remain open until.  Once an auction has start, the NFT owner can cancel the auction at any time.

While an auction remains open, anyone can place a bid for an item, so long as the bid they are placing satisfies the following criteria:

* The user must have enough available (i.e. unlocked) balance on the system to cover the bid.
* The bid is higher than the previously highest bid if any, and is higher than the reserve price.

Once these two criteria are met, the bid is placed, and recorded along with all other bids placed for the auction item.

Once the auction closes, anyone is free to complete the auction and execute settlement.  This will result in the following actions:

* The NFT is transferred to the bidder who placed the highest bid.
* The tokens that the highest bidder placed in escrow are transferred to the seller.
* All other tokens held in escrow are released to the unsuccessful bidders.
* The auction for the item are reset, allowing a new auction to be created by the item's seller.

If the seller cancels the auction, then all funds that are held in escrow are returned to the bidders.

In order to start an auction, an NFT owner must pay a fee.  This is to prevent spoofing, whereby auctions are created, but then cancelled before they reach their stated close, in order to make it appear that item is more valuable than it is.

When an NFT is sold, a fee goes to the system from the sale of the NFT, which 0.3% of the amount sold.
