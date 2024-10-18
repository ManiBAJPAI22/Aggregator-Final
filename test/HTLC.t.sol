// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/HTLC.sol";

// Separate malicious contract definition
contract MaliciousReceiver {
    HTLC public targetContract;
    bytes32 public preimage;
    
    receive() external payable {
        // Attempt reentrancy
        if(address(targetContract).balance > 0) {
            targetContract.unlock(preimage);
        }
    }
    
    function attack(HTLC _target, bytes32 _preimage) external {
        targetContract = _target;
        preimage = _preimage;
        targetContract.unlock(preimage);
    }
}

contract HTLCTest is Test {
    HTLC htlc;
    address payable receiver;
    address payable sender;
    address payable thirdParty;
    address payable maliciousActor;
    bytes32 preimage;
    bytes32 hashLock;
    uint256 timeLock;
    uint256 testAmount = 1 ether;
    uint256 constant MAX_TIMELOCK = 52 weeks;
    
    event Locked(address sender, uint256 amount, bytes32 hashLock, uint256 timeLock);
    event Unlocked(address receiver, uint256 amount, bytes32 preimage);
    event Refunded(address sender, uint256 amount);
    
    error InvalidPreimage();
    error TimeLockExpired();
    error UnauthorizedAccess();
    error FundsAlreadyLocked();
    
    struct TestCase {
        address sender;
        address receiver;
        uint256 amount;
        bytes32 hashLock;
        uint256 timeLock;
        bool shouldSucceed;
        string expectedError;
    }
    
    function setUp() public {
        // Setup main accounts
        receiver = payable(makeAddr("receiver"));
        sender = payable(address(this));
        thirdParty = payable(makeAddr("thirdParty"));
        maliciousActor = payable(makeAddr("maliciousActor"));
        
        // Setup basic parameters
        preimage = bytes32("secret");
        hashLock = keccak256(abi.encodePacked(preimage));
        timeLock = 1 hours;
        
        // Label addresses for better trace output
        vm.label(receiver, "Receiver");
        vm.label(sender, "Sender");
        vm.label(thirdParty, "ThirdParty");
        vm.label(maliciousActor, "MaliciousActor");
        
        // Fund accounts
        vm.deal(sender, 100 ether);
        vm.deal(receiver, 10 ether);
        vm.deal(thirdParty, 10 ether);
        vm.deal(maliciousActor, 10 ether);
        
        // Deploy initial contract
        htlc = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
    }

    // ==================== Constructor Tests ====================
    
    function testConstructorParameterValidation() public {
        TestCase[] memory testCases = new TestCase[](6);
        
        // Valid case
        testCases[0] = TestCase({
            sender: address(this),
            receiver: receiver,
            amount: 1 ether,
            hashLock: hashLock,
            timeLock: 1 hours,
            shouldSucceed: true,
            expectedError: ""
        });
        
        // Zero value
        testCases[1] = TestCase({
            sender: address(this),
            receiver: receiver,
            amount: 0,
            hashLock: hashLock,
            timeLock: 1 hours,
            shouldSucceed: false,
            expectedError: "Funds must be greater than 0"
        });
        
        // Zero address receiver
        testCases[2] = TestCase({
            sender: address(this),
            receiver: address(0),
            amount: 1 ether,
            hashLock: hashLock,
            timeLock: 1 hours,
            shouldSucceed: false,
            expectedError: "Invalid receiver address"
        });
        
        // Execute test cases
        for (uint i = 0; i < testCases.length; i++) {
            TestCase memory tc = testCases[i];
            if (tc.shouldSucceed) {
                new HTLC{value: tc.amount}(tc.receiver, tc.hashLock, tc.timeLock);
            } else {
                vm.expectRevert(bytes(tc.expectedError));
                new HTLC{value: tc.amount}(tc.receiver, tc.hashLock, tc.timeLock);
            }
        }
    }

    function testConstructorEvents() public {
        vm.recordLogs();
        htlc = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 1);
        
        // Verify Locked event
        assertEq(entries[0].topics[0], keccak256("Locked(address,uint256,bytes32,uint256)"));
        
        // Decode event data
        (address eventSender, uint256 eventAmount, bytes32 eventHashLock, uint256 eventTimeLock) = 
            abi.decode(entries[0].data, (address, uint256, bytes32, uint256));
        
        assertEq(eventSender, address(this));
        assertEq(eventAmount, testAmount);
        assertEq(eventHashLock, hashLock);
        assertEq(eventTimeLock, timeLock);
    }

    // ==================== Security Tests ====================
    
    function testReentrancyProtection() public {
        // Deploy malicious receiver contract
        MaliciousReceiver maliciousReceiver = new MaliciousReceiver();
        
        // Fund and create HTLC with malicious receiver
        htlc = new HTLC{value: testAmount}(address(maliciousReceiver), hashLock, timeLock);
        
        // Attempt reentrancy attack
        vm.prank(address(maliciousReceiver));
        vm.expectRevert();
        htlc.unlock(preimage);
    }
    
    function testDOSProtection() public {
        // Test with extremely large timelocks
        vm.expectRevert();
        new HTLC{value: testAmount}(receiver, hashLock, type(uint256).max);
        
        // Test with zero timelock
        vm.expectRevert();
        new HTLC{value: testAmount}(receiver, hashLock, 0);
    }
    
    function testFrontRunningProtection() public {
        // Simulate front-running scenario
        vm.prank(maliciousActor);
        vm.expectRevert();
        htlc.unlock(preimage);
        
        // Legitimate unlock should still work
        vm.prank(receiver);
        htlc.unlock(preimage);
    }

    // ==================== Business Logic Tests ====================
    
    function testUnlockScenarios() public {
        // Test successful unlock
        vm.prank(receiver);
        htlc.unlock(preimage);
        
        // Test unlock with wrong preimage
        htlc = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
        vm.prank(receiver);
        vm.expectRevert("Invalid preimage");
        htlc.unlock(bytes32("wrong"));
        
        // Test unlock after timelock expiry
        htlc = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
        vm.warp(block.timestamp + timeLock + 1);
        vm.prank(receiver);
        vm.expectRevert("Time lock has expired");
        htlc.unlock(preimage);
    }
    
    function testRefundScenarios() public {
        // Test successful refund
        vm.warp(block.timestamp + timeLock + 1);
        htlc.refund();
        
        // Test refund before timelock expiry
        htlc = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
        vm.expectRevert("Time lock has not expired");
        htlc.refund();
        
        // Test refund by non-sender
        htlc = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
        vm.warp(block.timestamp + timeLock + 1);
        vm.prank(thirdParty);
        vm.expectRevert("Only the sender can refund funds");
        htlc.refund();
    }

    // ==================== Edge Case Tests ====================
    
    function testTimeLockEdgeCases() public {
        // Test at exact timelock expiry
        htlc = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
        vm.warp(block.timestamp + timeLock);
        vm.prank(receiver);
        htlc.unlock(preimage);
        
        // Test one second after timelock
        htlc = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
        vm.warp(block.timestamp + timeLock + 1);
        htlc.refund();
        
        // Test maximum reasonable timelock
        htlc = new HTLC{value: testAmount}(receiver, hashLock, MAX_TIMELOCK);
        assertEq(htlc.timeLock(), block.timestamp + MAX_TIMELOCK);
    }
    
    function testAmountEdgeCases() public {
        // Test with minimal amount
        htlc = new HTLC{value: 1}(receiver, hashLock, timeLock);
        assertEq(address(htlc).balance, 1);
        
        // Test with large amount
        htlc = new HTLC{value: 100 ether}(receiver, hashLock, timeLock);
        assertEq(address(htlc).balance, 100 ether);
    }
    
    function testHashLockEdgeCases() public {
        // Test with zero preimage
        bytes32 zeroPreimage = bytes32(0);
        bytes32 zeroHash = keccak256(abi.encodePacked(zeroPreimage));
        htlc = new HTLC{value: testAmount}(receiver, zeroHash, timeLock);
        
        vm.prank(receiver);
        htlc.unlock(zeroPreimage);
        
        // Test with max value preimage
        bytes32 maxPreimage = bytes32(type(uint256).max);
        bytes32 maxHash = keccak256(abi.encodePacked(maxPreimage));
        htlc = new HTLC{value: testAmount}(receiver, maxHash, timeLock);
        
        vm.prank(receiver);
        htlc.unlock(maxPreimage);
    }

    // ==================== Stress Tests ====================
    
    function testMultipleContracts() public {
        HTLC[] memory contracts = new HTLC[](10);
        
        // Create multiple contracts
        for(uint i = 0; i < 10; i++) {
            contracts[i] = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
        }
        
        // Test different operations on different contracts
        for(uint i = 0; i < 10; i++) {
            if(i % 2 == 0) {
                vm.prank(receiver);
                contracts[i].unlock(preimage);
            } else {
                vm.warp(block.timestamp + timeLock + 1);
                contracts[i].refund();
            }
        }
    }
    
    function testConcurrentOperations() public {
        // Setup multiple contracts with same parameters
        HTLC htlc1 = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
        HTLC htlc2 = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
        HTLC htlc3 = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
        
        // Simulate concurrent operations
        vm.prank(receiver);
        htlc1.unlock(preimage);
        
        vm.warp(block.timestamp + timeLock + 1);
        htlc2.refund();
        
        vm.prank(receiver);
        htlc3.unlock(preimage);
    }

    // ==================== Gas Analysis Tests ====================
    
    function testGasUsageUnlock() public {
        uint256[] memory gasUsage = new uint256[](5);
        
        for(uint i = 0; i < 5; i++) {
            HTLC newHtlc = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
            vm.prank(receiver);
            
            uint256 gasStart = gasleft();
            newHtlc.unlock(preimage);
            gasUsage[i] = gasStart - gasleft();
        }
        
        // Log gas usage statistics
        uint256 totalGas = 0;
        for(uint i = 0; i < gasUsage.length; i++) {
            totalGas += gasUsage[i];
        }
        
        emit log_named_uint("Average gas used for unlock", totalGas / gasUsage.length);
    }
    
    function testGasUsageRefund() public {
        uint256[] memory gasUsage = new uint256[](5);
        
        for(uint i = 0; i < 5; i++) {
            HTLC newHtlc = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
            vm.warp(block.timestamp + timeLock + 1);
            
            uint256 gasStart = gasleft();
            newHtlc.refund();
            gasUsage[i] = gasStart - gasleft();
        }
        
        // Log gas usage statistics
        uint256 totalGas = 0;
        for(uint i = 0; i < gasUsage.length; i++) {
            totalGas += gasUsage[i];
        }
        
        emit log_named_uint("Average gas used for refund", totalGas / gasUsage.length);
    }

    receive() external payable {}
}