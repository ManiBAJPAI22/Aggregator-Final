const ethers = require('ethers');
const config = require('./config');

// Function to relay proof to Morph chain
const relayToMorph = async (hashLock) => {
    const signer = new ethers.Wallet(config.privateKey, new ethers.providers.JsonRpcProvider(config.morphRpcUrl));
    const morphHtlcContract = new ethers.Contract(config.morphHtlcAddress, config.htlcABI, signer);

    // Replace this with actual preimage logic based on your setup
    const preimage = "<PREIMAGE>";

    try {
        const tx = await morphHtlcContract.unlock(preimage);
        console.log(`Unlocking on Morph: ${tx.hash}`);
        await tx.wait();
        console.log(`Unlocked on Morph chain`);
    } catch (error) {
        console.error("Error unlocking on Morph:", error);
    }
};

// Function to relay proof to Manta chain
const relayToManta = async (hashLock) => {
    const signer = new ethers.Wallet(config.privateKey, new ethers.providers.JsonRpcProvider(config.mantaRpcUrl));
    const mantaHtlcContract = new ethers.Contract(config.mantaHtlcAddress, config.htlcABI, signer);

    // Replace this with actual preimage logic based on your setup
    const preimage = "<PREIMAGE>";

    try {
        const tx = await mantaHtlcContract.unlock(preimage);
        console.log(`Unlocking on Manta: ${tx.hash}`);
        await tx.wait();
        console.log(`Unlocked on Manta chain`);
    } catch (error) {
        console.error("Error unlocking on Manta:", error);
    }
};

module.exports = { relayToMorph, relayToManta };
