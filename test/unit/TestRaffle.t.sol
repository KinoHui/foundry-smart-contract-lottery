// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract TestRaffle is Test {
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    address PLAYER = makeAddr("player");
    uint256 constant STARTING_PLAYER_BALANCE = 10 ether;
    uint256 constant ENTER_FEE = 0.01 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        raffle = deployRaffle.run();
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testStateOfRaffleIsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWHenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: ENTER_FEE}();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + raffle.getInterval() + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueIfItHasBalance() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTER_FEE}();

        vm.warp(block.timestamp + raffle.getInterval() + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTER_FEE}();
        vm.warp(block.timestamp + raffle.getInterval() + 1);
        vm.roll(block.number + 1);
        console.log("state before perform: ", uint256(raffle.getRaffleState()));
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        console.log("state after perform: ", uint256(raffleState));

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(upkeepNeeded == false);
    }

    function testEmitsEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: ENTER_FEE}();
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTER_FEE}();
        vm.warp(block.timestamp + raffle.getInterval() + 1);
        vm.roll(block.number + 1);

        // Act
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public skipFork {
        // Arrange
        uint256 initialBalance = 0;
        uint256 numPlayers = 0;
        uint256 state = uint256(raffle.getRaffleState());

        // Act
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTER_FEE}();
        initialBalance += ENTER_FEE;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                initialBalance,
                numPlayers + 1,
                state
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTER_FEE}();
        vm.warp(block.timestamp + raffle.getInterval() + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEntredAndTimePassed
    {
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint(raffleState) == 1); // 0 = open, 1 = calculating
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 requestId
    ) public raffleEntredAndTimePassed skipFork {
        // Arrange
        address vrfCoordinator = raffle.getVrfCoordinatorAddress();
        // Act / Assert
        vm.expectRevert("nonexistent request");
        // vm.mockCall could be used here...
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerRestesAndSendsMoney()
        public
        raffleEntredAndTimePassed
        skipFork
    {
        // Arrange
        address vrfCoordinator = raffle.getVrfCoordinatorAddress();
        uint256 startingIndex = 1;
        uint256 additionalEntrants = 5;

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_PLAYER_BALANCE);
            raffle.enterRaffle{value: ENTER_FEE}();
        }

        uint256 prize = ENTER_FEE * (additionalEntrants + 1);

        // we need to pretend to be Chainlink VRF and call `fulfillRandomWords`.
        // We will need the `requestId` and the `consumer`
        // use the messages emited to get `requestId`
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        // pretend to be Chainlink VRF
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        assertEq(uint256(raffle.getRaffleState()), 0);
        assertTrue(raffle.getRecentWinner() != address(0));
        assertEq(raffle.getNumberOfPlayers(), 0);
        assertGt(raffle.getLastTimeStamp(), previousTimeStamp);

        assertEq(
            raffle.getRecentWinner().balance,
            STARTING_PLAYER_BALANCE + prize - ENTER_FEE
        );
    }
}
