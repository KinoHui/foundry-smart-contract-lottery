// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle
 * @author jyh
 * @notice A comprehensive contract
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /**ERRORS */
    error Raffle__NotEnoughToEntrance();

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entrancePrice;
    // @dev duration of the lottery last (unit "s")
    uint256 private immutable i_interval;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint256 private s_lastTimestamp;
    address payable[] private s_players;

    event RaffleEntered(address indexed player);

    // 这里继承了VRFConsumerBaseV2Plus合约，该合约也有自己的constructor，因此在Raffle合约中的constructor参数中传递VRFC..合约构造函数所需的参数
    constructor(
        uint256 entrance,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entrancePrice = entrance;
        i_interval = interval;
        s_lastTimestamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
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

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        // get a random number from chainlink VRF v2.5
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {}

    function getEntrancePrice() external view returns (uint256) {
        return i_entrancePrice;
    }
}
