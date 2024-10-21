// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/HTLCFactory.sol";

contract DeployHTLCFactory is Script {
    function run() external {
        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy HTLCFactory contract
        HTLCFactory htlcFactory = new HTLCFactory();

        // Print the deployed contract address
        console.log("HTLCFactory deployed at:", address(htlcFactory));

        // Stop broadcasting
        vm.stopBroadcast();
    }
}
