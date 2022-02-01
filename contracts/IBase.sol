// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "hardhat/console.sol";

/**
 * @title Coordinator
 * @dev Voting for NFTs
 */
interface IBase {

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