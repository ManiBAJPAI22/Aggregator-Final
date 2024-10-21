const ethers = require('ethers');
const config = require('./config');

// Relayer wallet for signing transactions on both chains
const mantaSigner = new ethers.Wallet(config.privateKey, new ethers.providers.JsonRpcProvider(config.mantaRpcUrl));
const morphSigner = new ethers.Wallet(config.privateKey, new ethers.providers.JsonRpcProvider(config.morphRpcUrl));

// Function to relay proof to the Morph chain (unlock HTLC contract on Morph)
const relayToMorph = async (htlcAddress, preimage) => {
    try {
        const htlcContract = new ethers.Contract(htlcAddress, config.htlcABI, morphSigner);

        console.log(`Relaying proof to Morph for HTLC: ${htlcAddress}`);
        
        // Unlock the HTLC with the provided preimage
        const tx = await htlcContract.unlock(preimage);
        console.log(`Unlock transaction sent on Morph chain. TX Hash: ${tx.hash}`);
        
        // Wait for transaction confirmation
        await tx.wait();
        console.log(`HTLC unlocked on Morph chain: ${htlcAddress}`);
    } catch (error) {
        console.error("Error relaying proof to Morph:", error);
    }
};

// Function to relay proof to the Manta chain (unlock HTLC contract on Manta)
const relayToManta = async (htlcAddress, preimage) => {
    try {
        const htlcContract = new ethers.Contract(htlcAddress, config.htlcABI, mantaSigner);

        console.log(`Relaying proof to Manta for HTLC: ${htlcAddress}`);
        
        // Unlock the HTLC with the provided preimage
        const tx = await htlcContract.unlock(preimage);
        console.log(`Unlock transaction sent on Manta chain. TX Hash: ${tx.hash}`);
        
        // Wait for transaction confirmation
        await tx.wait();
        console.log(`HTLC unlocked on Manta chain: ${htlcAddress}`);
    } catch (error) {
        console.error("Error relaying proof to Manta:", error);
    }
};

// Function to trigger refund on the Morph chain if the time lock has expired
const refundOnMorph = async (htlcAddress) => {
    try {
        const htlcContract = new ethers.Contract(htlcAddress, config.htlcABI, morphSigner);

        console.log(`Triggering refund on Morph for HTLC: ${htlcAddress}`);
        
        // Call refund on the HTLC contract
        const tx = await htlcContract.refund();
        console.log(`Refund transaction sent on Morph chain. TX Hash: ${tx.hash}`);
        
        // Wait for transaction confirmation
        await tx.wait();
        console.log(`Refund processed on Morph chain: ${htlcAddress}`);
    } catch (error) {
        console.error("Error triggering refund on Morph:", error);
    }
};

// Function to trigger refund on the Manta chain if the time lock has expired
const refundOnManta = async (htlcAddress) => {
    try {
        const htlcContract = new ethers.Contract(htlcAddress, config.htlcABI, mantaSigner);

        console.log(`Triggering refund on Manta for HTLC: ${htlcAddress}`);
        
        // Call refund on the HTLC contract
        const tx = await htlcContract.refund();
        console.log(`Refund transaction sent on Manta chain. TX Hash: ${tx.hash}`);
        
        // Wait for transaction confirmation
        await tx.wait();
        console.log(`Refund processed on Manta chain: ${htlcAddress}`);
    } catch (error) {
        console.error("Error triggering refund on Manta:", error);
    }
};

module.exports = { relayToMorph, relayToManta, refundOnMorph, refundOnManta };
