require('dotenv').config();

module.exports = {
    // RPC URLs for Manta and Morph testnets
    mantaRpcUrl: process.env.MANTA_RPC_URL,
    morphRpcUrl: process.env.MORPH_RPC_URL,

    // Private key for signing transactions
    privateKey: process.env.PRIVATE_KEY,

    // HTLC Factory contract addresses
    mantaFactoryAddress: process.env.MANTA_FACTORY_ADDRESS,
    morphFactoryAddress: process.env.MORPH_FACTORY_ADDRESS,

    // ABI for HTLCFactory and HTLC contracts
    factoryABI: [
        // Add ABI for the factory contract here
    ],
    htlcABI: [
        // Add ABI for the HTLC contract here
    ],
};
