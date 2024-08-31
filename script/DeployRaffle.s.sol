// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelpConfig} from "./HelpConfig.s.sol";

contract DeployRaffle is Script {
    function run() public returns (Raffle) {
        (Raffle raffle, ) = deployContract();
        return raffle;
    }

    function deployContract() public returns (Raffle, HelpConfig) {
        HelpConfig helpConfig = new HelpConfig();
        HelpConfig.NetworkConfig memory config = helpConfig.getConfig();

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();
        return (raffle, helpConfig);
    }
}
