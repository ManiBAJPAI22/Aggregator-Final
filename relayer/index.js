const { listenToEvents } = require('./eventListeners');

async function main() {
    console.log("Starting relayer service...");
    listenToEvents();
}

main().catch((error) => {
    console.error("Error in relayer service:", error);
});
