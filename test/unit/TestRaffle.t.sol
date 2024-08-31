// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";

contract TestRaffle is Test {
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
}
