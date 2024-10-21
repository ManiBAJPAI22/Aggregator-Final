// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/HTLCFactory.sol";
import "../src/HTLC.sol";

contract HTLCFactoryTest is Test {
    HTLCFactory factory;
    event HTLCDeployed(address htlcAddress);

    function setUp() public {
        factory = new HTLCFactory();
    }

    function testCreateHTLC() public {
        address receiver = address(0x123);
        bytes32 hashLock = keccak256(abi.encodePacked("secret"));
        uint256 timeLock = 1 hours;

        address newHTLC = factory.createHTLC{value: 1 ether}(receiver, hashLock, timeLock);

        assertTrue(newHTLC != address(0));

        HTLC[] memory htlcs = factory.getDeployedHTLCs();
        assertEq(htlcs.length, 1);
        assertEq(address(htlcs[0]), newHTLC);
    }

    function testEventEmissionOnHTLCDeploy() public {
        address receiver = address(0x123);
        bytes32 hashLock = keccak256(abi.encodePacked("secret"));
        uint256 timeLock = 1 hours;

        // Record events
        vm.recordLogs();
        
        // Deploy the contract
        address newHTLCAddress = factory.createHTLC{value: 1 ether}(receiver, hashLock, timeLock);

        // Get logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        
        // Verify we have logs
        assertGt(entries.length, 0, "No events were emitted");
        
        // Get the last entry (should be our deployment event)
        Vm.Log memory lastEntry = entries[entries.length - 1];
        
        // Verify event signature
        bytes32 expectedEventSignature = keccak256("HTLCDeployed(address)");
        assertEq(lastEntry.topics[0], expectedEventSignature, "Wrong event signature");

        // If the address parameter is not indexed, it will be in the data field
        address emittedAddress = abi.decode(lastEntry.data, (address));
        
        // Verify the address matches
        assertEq(emittedAddress, newHTLCAddress, "Emitted address doesn't match created HTLC address");
    }

    function testFailCreateHTLCWithoutETH() public {
        address receiver = address(0x123);
        bytes32 hashLock = keccak256(abi.encodePacked("secret"));
        uint256 timeLock = 1 hours;

        factory.createHTLC(receiver, hashLock, timeLock);
    }
}