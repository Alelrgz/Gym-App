/**
 * WebSocket Module
 * Handles real-time connection for hot reload and data refresh
 */

let socket = null;

export function initWebSocket(apiBase, onRefreshCallback) {
    const clientId = Date.now().toString();
    const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
    const wsHost = apiBase ? apiBase.replace('http', 'ws') : `${protocol}://${window.location.host}`;
    const wsUrl = `${wsHost}/ws/${clientId}`;

    socket = new WebSocket(wsUrl);

    socket.onmessage = function (event) {
        const data = JSON.parse(event.data);
        if (data.type === 'reload') {
            console.log("Reloading due to code change...");
            window.location.reload();
        } else if (data.type === 'refresh') {
            console.log("Refreshing data...", data.target);
            // Call the refresh callback (typically init())
            if (onRefreshCallback) {
                onRefreshCallback();
            }
        }
    };

    socket.onopen = () => console.log("Connected to Real-Time Engine");
    socket.onclose = () => console.log("Disconnected from Real-Time Engine");

    return socket;
}

export function getSocket() {
    return socket;
}
