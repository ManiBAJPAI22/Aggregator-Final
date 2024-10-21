const { listenToFactoryEvents } = require('./eventListeners');

async function main() {
    console.log("Starting relayer service...");
    
    // Start listening to events from the HTLC Factory on both Manta and Morph chains
    listenToFactoryEvents();
}

main().catch((error) => {
    console.error("Error in relayer service:", error);
});
