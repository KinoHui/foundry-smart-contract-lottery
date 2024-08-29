// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Raffle
 * @author jyh
 * @notice A comprehensive contract
 */
contract Raffle {
    /**ERRORS */
    error Raffle__NotEnoughToEntrance();

    uint256 private immutable i_entrancePrice;
    // @dev duration of the lottery last (unit "s")
    uint256 private immutable i_interval;
    uint256 private s_lastTimestamp;
    address payable[] private s_players;

    event RaffleEntered(address indexed player);

    constructor(uint256 entrance, uint256 interval) {
        i_entrancePrice = entrance;
        i_interval = interval;
        s_lastTimestamp = block.timestamp;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entrancePrice) {
            revert Raffle__NotEnoughToEntrance();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // 1. generate a random number
    // 2. use the random number to pick a winner
    // 3. automatic pick with the interval
    function pickWinner() public {
        if ((block.timestamp - s_lastTimestamp) < i_interval) {
            revert();
        }

        // get a random number from chainlink VRF v2.5
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    function getEntrancePrice() external view returns (uint256) {
        return i_entrancePrice;
    }
}
