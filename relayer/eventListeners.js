const ethers = require('ethers');
const config = require('./config');

// Set up providers for Manta and Morph networks
const mantaProvider = new ethers.providers.JsonRpcProvider(config.mantaRpcUrl);
const morphProvider = new ethers.providers.JsonRpcProvider(config.morphRpcUrl);

// HTLC Factory Contract Instances
const mantaFactory = new ethers.Contract(config.mantaFactoryAddress, config.factoryABI, mantaProvider);
const morphFactory = new ethers.Contract(config.morphFactoryAddress, config.factoryABI, morphProvider);

// Function to listen to HTLCDeployed event from the HTLCFactory and monitor new HTLC contracts
const listenToFactoryEvents = () => {
    // Manta chain
    mantaFactory.on('HTLCDeployed', async (htlcAddress) => {
        console.log(`HTLC deployed on Manta: ${htlcAddress}`);
        await monitorHTLC(htlcAddress, mantaProvider);
    });

    // Morph chain
    morphFactory.on('HTLCDeployed', async (htlcAddress) => {
        console.log(`HTLC deployed on Morph: ${htlcAddress}`);
        await monitorHTLC(htlcAddress, morphProvider);
    });
};

// Monitor events from the newly deployed HTLC contract
const monitorHTLC = async (htlcAddress, provider) => {
    const htlcContract = new ethers.Contract(htlcAddress, config.htlcABI, provider);

    // Listen for Lock event
    htlcContract.on('Locked', (sender, amount, hashLock, timeLock) => {
        console.log(`Locked: Sender: ${sender}, Amount: ${amount}, HashLock: ${hashLock}`);
    });

    // Listen for Unlock event
    htlcContract.on('Unlocked', (receiver, amount, preimage) => {
        console.log(`Unlocked: Receiver: ${receiver}, Amount: ${amount}, Preimage: ${preimage}`);
    });

    // Listen for Refund event
    htlcContract.on('Refunded', (sender, amount) => {
        console.log(`Refunded: Sender: ${sender}, Amount: ${amount}`);
    });
};

module.exports = { listenToFactoryEvents };
