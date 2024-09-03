// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";

contract TestRaffle is Test {
    event RaffleEntered(address indexed player);

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
        vm.expectRevert(Raffle.Raffle__NotEnoughToEntrance.selector);
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
        emit RaffleEntered(PLAYER);
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

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
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
}
