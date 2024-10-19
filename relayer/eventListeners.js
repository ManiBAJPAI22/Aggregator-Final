const { ethers } = require("ethers");

const config = require('./config');

// Set up providers for Manta and Morph
const mantaProvider = new ethers.providers.JsonRpcProvider(config.mantaRpcUrl);
const morphProvider = new ethers.providers.JsonRpcProvider(config.morphRpcUrl);

// Set up wallet using private key
const wallet = new ethers.Wallet(config.privateKey);

// HTLC contract instances
const mantaHtlcContract = new ethers.Contract(config.mantaHtlcAddress, config.htlcABI, wallet.connect(mantaProvider));
const morphHtlcContract = new ethers.Contract(config.morphHtlcAddress, config.htlcABI, wallet.connect(morphProvider));

const listenToEvents = () => {
    // Listening to Locked event on Manta chain
    mantaHtlcContract.on("Locked", async (sender, amount, hashLock, timeLock) => {
        console.log(`HTLC Locked on Manta: Sender: ${sender}, Amount: ${amount}, HashLock: ${hashLock}`);

        // Call a function to relay the cryptographic proof to Morph chain
        await relayToMorph(hashLock);
    });

    // Listening to Locked event on Morph chain
    morphHtlcContract.on("Locked", async (sender, amount, hashLock, timeLock) => {
        console.log(`HTLC Locked on Morph: Sender: ${sender}, Amount: ${amount}, HashLock: ${hashLock}`);

        // Call a function to relay the cryptographic proof to Manta chain
        await relayToManta(hashLock);
    });
};

module.exports = { listenToEvents };
