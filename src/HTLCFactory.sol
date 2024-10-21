// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HTLC.sol";

contract HTLCFactory {
    HTLC[] public deployedHTLCs;

    event HTLCDeployed(address htlcAddress);

    function createHTLC(address _receiver, bytes32 _hashLock, uint256 _timeLock) public payable returns (address) {
        require(msg.value > 0, "Must send ETH to lock in HTLC");

        // Deploy a new HTLC contract
        HTLC newHTLC = new HTLC{value: msg.value}(_receiver, _hashLock, _timeLock);

        deployedHTLCs.push(newHTLC);

        emit HTLCDeployed(address(newHTLC));  // Ensure event is emitted correctly

        return address(newHTLC);
    }

    function getDeployedHTLCs() public view returns (HTLC[] memory) {
        return deployedHTLCs;
    }
}
