require('dotenv').config();

module.exports = {
    mantaRpcUrl: process.env.MANTA_RPC_URL,
    morphRpcUrl: process.env.MORPH_RPC_URL,
    privateKey: process.env.PRIVATE_KEY,
    mantaHtlcAddress: "<HTLC_CONTRACT_ADDRESS_ON_MANTA>",
    morphHtlcAddress: "<HTLC_CONTRACT_ADDRESS_ON_MORPH>",
    htlcABI: [
        // Your HTLC contract ABI here
    ]
};
