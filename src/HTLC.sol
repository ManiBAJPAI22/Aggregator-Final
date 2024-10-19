// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";

contract HTLC is ReentrancyGuard, Pausable {
    address public immutable sender;
    address public immutable receiver;
    uint256 private _amount;
    bytes32 public immutable hashLock;
    uint256 public immutable timeLock;
    bool private _completed;
    bool private _refunded;
    
    uint256 public constant MIN_TIMELOCK = 1 hours;
    uint256 public constant MAX_TIMELOCK = 52 weeks;
    
    event Locked(address sender, uint256 amount, bytes32 hashLock, uint256 timeLock);
    event Unlocked(address receiver, uint256 amount, bytes32 preimage);
    event Refunded(address sender, uint256 amount);
    
    error InvalidAmount();
    error InvalidReceiver();
    error InvalidSender();
    error InvalidTimeLock();
    error InvalidHashLock();
    error InvalidPreimage();
    error Unauthorized();
    error AlreadyCompleted();
    error AlreadyRefunded();
    error TimeLockNotExpired();
    error TimeLockExpired();
    error TransferFailed();
    
    modifier onlyReceiver() {
        if (msg.sender != receiver) revert Unauthorized();
        _;
    }
    
    modifier onlySender() {
        if (msg.sender != sender) revert Unauthorized();
        _;
    }
    
    constructor(
        address _receiver,
        bytes32 _hashLock,
        uint256 _timeLock
    ) payable {
        if (msg.value == 0) revert InvalidAmount();
        if (_receiver == address(0)) revert InvalidReceiver();
        if (_receiver == msg.sender) revert InvalidSender();
        if (_timeLock < MIN_TIMELOCK) revert InvalidTimeLock();
        if (_timeLock > MAX_TIMELOCK) revert InvalidTimeLock();
        if (_hashLock == bytes32(0)) revert InvalidHashLock();
        
        sender = msg.sender;
        receiver = _receiver;
        _amount = msg.value;
        hashLock = _hashLock;
        timeLock = block.timestamp + _timeLock;
        
        emit Locked(msg.sender, msg.value, _hashLock, _timeLock);
    }
    
    function amount() external view returns (uint256) {
        return _amount;
    }
    
    function isCompleted() external view returns (bool) {
        return _completed;
    }
    
    function isRefunded() external view returns (bool) {
        return _refunded;
    }
    
    function unlock(bytes32 preimage) external nonReentrant whenNotPaused onlyReceiver {
        if (_completed) revert AlreadyCompleted();
        if (_refunded) revert AlreadyRefunded();
        if (keccak256(abi.encodePacked(preimage)) != hashLock) revert InvalidPreimage();
        if (block.timestamp > timeLock) revert TimeLockExpired();
        
        uint256 amountToSend = _amount;
        _amount = 0;
        _completed = true;
        
        (bool success, ) = payable(receiver).call{value: amountToSend}("");
        if (!success) {
            _amount = amountToSend;
            _completed = false;
            revert TransferFailed();
        }
        
        emit Unlocked(receiver, amountToSend, preimage);
    }
    
    function refund() external nonReentrant whenNotPaused onlySender {
        if (block.timestamp <= timeLock) revert TimeLockNotExpired();
        if (_completed) revert AlreadyCompleted();
        if (_refunded) revert AlreadyRefunded();
        
        uint256 amountToRefund = _amount;
        _amount = 0;
        _refunded = true;
        
        (bool success, ) = payable(sender).call{value: amountToRefund}("");
        if (!success) {
            _amount = amountToRefund;
            _refunded = false;
            revert TransferFailed();
        }
        
        emit Refunded(sender, amountToRefund);
    }
    
    function pause() external onlySender {
        _pause();
    }
    
    function unpause() external onlySender {
        _unpause();
    }
}
