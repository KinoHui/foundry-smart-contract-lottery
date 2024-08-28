// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**ERRORS */
error Raffle__NotEnoughToEntrance;

/**
 * @title Raffle
 * @author jyh
 * @notice A comprehensive contract 
 */
contract Raffle {
    uint256 private immutable i_entrancePrice;

    constructor(uint256 entrance) {
        i_entrancePrice = entrance;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entrancePrice) {
            revert Raffle__NotEnoughToEntrance();
        }
    }

    function pickWinner() public {}

    function getEntrancePrice() external returns (uint256) {
        return i_entrancePrice;
    }
}
