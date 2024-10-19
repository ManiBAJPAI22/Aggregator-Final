// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/HTLC.sol";

contract MaliciousReceiver {
    HTLC public targetContract;
    bytes32 public preimage;
    uint256 public attackCount;
    
    constructor() {
        attackCount = 0;
    }
    
    receive() external payable {
        if (attackCount == 0) {
            attackCount++;
            targetContract.unlock(preimage);
        }
    }
       function attack(HTLC _target, bytes32 _preimage) external {
        targetContract = _target;
        preimage = _preimage;
        attackCount = 0;
        targetContract.unlock(preimage);
    }
}


contract NonPayableContract {
    // This contract will refuse to accept Ether
    receive() external payable {
        revert("NonPayableContract: Cannot accept Ether");
    }
}

contract HTLCTest is Test {
     HTLC htlc;
    address payable receiver;
    address payable sender;
    bytes32 preimage;
    bytes32 hashLock;
    uint256 timeLock;
    uint256 testAmount = 10 ether;

    function setUp() public {
        vm.deal(address(this), 100 ether);

        receiver = payable(makeAddr("receiver"));  
        sender = payable(address(this));           
        vm.deal(receiver, 1 ether);                

        preimage = bytes32("secret");               
        hashLock = keccak256(abi.encodePacked(preimage)); 
        timeLock = 1 hours;                        
        
        htlc = new HTLC{value: testAmount}(receiver, hashLock, timeLock);
    }
    
    receive() external payable {}

    function testReentrancyProtection() public {
        MaliciousReceiver maliciousReceiver = new MaliciousReceiver();
        vm.deal(address(maliciousReceiver), 1 ether);

        HTLC newHtlc = new HTLC{value: 2 ether}(
            address(maliciousReceiver),
            hashLock,
            timeLock
        );

        vm.startPrank(address(maliciousReceiver));

        vm.expectRevert();  
        maliciousReceiver.attack(newHtlc, preimage);
        
        vm.stopPrank();

        assertEq(maliciousReceiver.attackCount(), 0, "Reentrancy attack should not have been successful");
    }

    function testRefundScenarios() public {
        vm.expectRevert(HTLC.TimeLockNotExpired.selector);
        htlc.refund();

        vm.warp(block.timestamp + timeLock + 1);

        uint256 balanceBefore = address(this).balance;
        htlc.refund();
        uint256 balanceAfter = address(this).balance;

        assertEq(balanceAfter - balanceBefore, testAmount, "Refund should be successful");
        assertEq(address(htlc).balance, 0, "Contract balance should be zero after refund");
    }

    function testUnlockScenarios() public {
        vm.startPrank(receiver);
        htlc.unlock(preimage);
        vm.stopPrank();

        vm.deal(address(this), 2 ether);
        htlc = new HTLC{value: 2 ether}(receiver, hashLock, timeLock);

        vm.startPrank(receiver);
        vm.expectRevert(HTLC.InvalidPreimage.selector);
        htlc.unlock(bytes32("wrong"));
        vm.stopPrank();

        vm.warp(block.timestamp + timeLock + 1);
        vm.startPrank(receiver);
        vm.expectRevert(HTLC.TimeLockExpired.selector);
        htlc.unlock(preimage);
        vm.stopPrank();
    }

    function testAmountEdgeCases() public {
        vm.deal(address(this), 2 ether);
        htlc = new HTLC{value: 1}(receiver, hashLock, timeLock);
        assertEq(address(htlc).balance, 1, "HTLC should have 1 wei balance");

        vm.expectRevert(HTLC.InvalidAmount.selector);
        new HTLC{value: 0}(receiver, hashLock, timeLock);
    }

    function testRefundWithoutExpiredTimeLock() public {
        vm.expectRevert(HTLC.TimeLockNotExpired.selector);
        htlc.refund();
    }

    function testUnlockWithWrongPreimage() public {
        vm.startPrank(receiver);
        bytes32 wrongPreimage = keccak256(abi.encodePacked("wrong"));
        
        vm.expectRevert(HTLC.InvalidPreimage.selector);
        htlc.unlock(wrongPreimage);
        
        vm.stopPrank();
    }

    function testUnlockAfterTimeLockExpired() public {
        vm.warp(block.timestamp + timeLock + 1);

        vm.startPrank(receiver);
        vm.expectRevert(HTLC.TimeLockExpired.selector);
        htlc.unlock(preimage);
        vm.stopPrank();
    }

    function testDoubleRefund() public {
        vm.warp(block.timestamp + timeLock + 1);

        uint256 balanceBefore = address(this).balance;
        htlc.refund();
        uint256 balanceAfter = address(this).balance;

        assertEq(balanceAfter - balanceBefore, testAmount, "Refund should be successful");

        vm.expectRevert(HTLC.AlreadyRefunded.selector);
        htlc.refund();
    }

    function testDoubleUnlock() public {
        vm.startPrank(receiver);

        uint256 balanceBefore = receiver.balance;
        htlc.unlock(preimage);
        uint256 balanceAfter = receiver.balance;

        assertEq(balanceAfter - balanceBefore, testAmount, "Receiver should receive the funds");

        vm.expectRevert(HTLC.AlreadyCompleted.selector);
        htlc.unlock(preimage);

        vm.stopPrank();
    }

    function testPauseAndRefund() public {
        uint256 initialBalance = address(this).balance;
        htlc.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        htlc.refund();

        htlc.unpause();
        vm.warp(block.timestamp + timeLock + 1);
        htlc.refund();
        
        uint256 balanceAfter = address(this).balance;
        assertEq(balanceAfter, initialBalance + testAmount, "Sender should be refunded after unpausing");
    }

    function testPauseAndUnpause() public {
        uint256 initialReceiverBalance = receiver.balance;
        htlc.pause();

        vm.startPrank(receiver);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        htlc.unlock(preimage);
        vm.stopPrank();

        htlc.unpause();

        vm.startPrank(receiver);
        htlc.unlock(preimage);

        uint256 balanceAfter = receiver.balance;
        assertEq(balanceAfter, initialReceiverBalance + testAmount, "Receiver should receive the funds after unpausing");
        vm.stopPrank();
    }

     function testCreateHTLCWithInvalidReceiver() public {
        vm.expectRevert(HTLC.InvalidReceiver.selector);
        new HTLC{value: 1 ether}(address(0), hashLock, timeLock);
    }

    function testCreateHTLCWithInvalidSender() public {
        vm.expectRevert(HTLC.InvalidSender.selector);
        new HTLC{value: 1 ether}(address(this), hashLock, timeLock);
    }

    function testCreateHTLCWithInvalidTimeLock() public {
        uint256 invalidShortTimeLock = 30 minutes; // Less than MIN_TIMELOCK
        uint256 invalidLongTimeLock = 53 weeks; // More than MAX_TIMELOCK

        vm.expectRevert(HTLC.InvalidTimeLock.selector);
        new HTLC{value: 1 ether}(receiver, hashLock, invalidShortTimeLock);

        vm.expectRevert(HTLC.InvalidTimeLock.selector);
        new HTLC{value: 1 ether}(receiver, hashLock, invalidLongTimeLock);
    }

    function testCreateHTLCWithInvalidHashLock() public {
        vm.expectRevert(HTLC.InvalidHashLock.selector);
        new HTLC{value: 1 ether}(receiver, bytes32(0), timeLock);
    }

    function testUnauthorizedPause() public {
        vm.prank(receiver);
        vm.expectRevert(HTLC.Unauthorized.selector);
        htlc.pause();
    }

    function testUnauthorizedUnpause() public {
        htlc.pause();
        
        vm.prank(receiver);
        vm.expectRevert(HTLC.Unauthorized.selector);
        htlc.unpause();
    }

    function testUnlockWithNonReceiverAddress() public {
        address nonReceiver = makeAddr("nonReceiver");
        
        vm.prank(nonReceiver);
        vm.expectRevert(HTLC.Unauthorized.selector);
        htlc.unlock(preimage);
    }

    function testRefundWithNonSenderAddress() public {
        address nonSender = makeAddr("nonSender");
        
        vm.warp(block.timestamp + timeLock + 1);
        vm.prank(nonSender);
        vm.expectRevert(HTLC.Unauthorized.selector);
        htlc.refund();
    }

     function testTransferFailure() public {
        // Create a contract that refuses to accept Ether
        NonPayableContract nonPayableContract = new NonPayableContract();
        
        bytes32 newPreimage = bytes32("newSecret");
        bytes32 newHashLock = keccak256(abi.encodePacked(newPreimage));
        HTLC newHtlc = new HTLC{value: 1 ether}(address(nonPayableContract), newHashLock, timeLock);
        
        vm.prank(address(nonPayableContract));
        vm.expectRevert(HTLC.TransferFailed.selector);
        newHtlc.unlock(newPreimage);
    }
}
