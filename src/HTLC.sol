// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";

contract HTLC is ReentrancyGuard, Pausable {
    address public sender;
    address public receiver;
    uint256 public amount;
    bytes32 public hashLock;
    uint256 public timeLock;
    bool public completed;
    bool public refunded;
    
    uint256 public constant MIN_TIMELOCK = 1 hours;
    uint256 public constant MAX_TIMELOCK = 30 days;
    
    event Locked(address sender, uint256 amount, bytes32 hashLock, uint256 timeLock);
    event Unlocked(address receiver, uint256 amount, bytes32 preimage);
    event Refunded(address sender, uint256 amount);
    
    constructor(
        address _receiver,
        bytes32 _hashLock,
        uint256 _timeLock
    ) payable {
        require(msg.value > 0, "Funds must be greater than 0");
        require(_receiver != address(0), "Invalid receiver address");
        require(_receiver != msg.sender, "Receiver cannot be sender");
        require(_timeLock >= MIN_TIMELOCK, "Timelock too short");
        require(_timeLock <= MAX_TIMELOCK, "Timelock too long");
        require(_hashLock != bytes32(0), "Invalid hashlock");
        
        sender = msg.sender;
        receiver = _receiver;
        amount = msg.value;
        hashLock = _hashLock;
        timeLock = block.timestamp + _timeLock;
        completed = false;
        refunded = false;
        
        emit Locked(msg.sender, msg.value, _hashLock, _timeLock);
    }
    
    function unlock(bytes32 preimage) external nonReentrant whenNotPaused {
        require(msg.sender == receiver, "Only the receiver can unlock funds");
        require(!completed, "Funds already unlocked");
        require(!refunded, "Funds already refunded");
        require(keccak256(abi.encodePacked(preimage)) == hashLock, "Invalid preimage");
        require(block.timestamp <= timeLock, "Time lock has expired");
        
        completed = true;
        
        // Update state before external call to prevent reentrancy
        uint256 amountToSend = amount;
        amount = 0;
        
        (bool success, ) = payable(receiver).call{value: amountToSend}("");
        require(success, "Transfer failed");
        
        emit Unlocked(receiver, amountToSend, preimage);
    }
    
    function refund() external nonReentrant whenNotPaused {
        require(msg.sender == sender, "Only the sender can refund funds");
        require(block.timestamp > timeLock, "Time lock has not expired");
        require(!completed, "Funds already unlocked");
        require(!refunded, "Funds already refunded");
        
        refunded = true;
        
        // Update state before external call to prevent reentrancy
        uint256 amountToRefund = amount;
        amount = 0;
        
        (bool success, ) = payable(sender).call{value: amountToRefund}("");
        require(success, "Transfer failed");
        
        emit Refunded(sender, amountToRefund);
    }
    
    // Emergency pause function (only owner)
    function pause() external {
        require(msg.sender == sender, "Only sender can pause");
        _pause();
    }
    
    function unpause() external {
        require(msg.sender == sender, "Only sender can unpause");
        _unpause();
    }
}
