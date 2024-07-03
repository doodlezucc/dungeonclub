import { getWebSocketServer, globalThisWSS, type ExtendedGlobal } from './web-socket-utils.js';

// Adapted from https://github.com/suhaildawood/SvelteKit-integrated-WebSocket

let wssInitialized = false;
export const setupWebsocketServer = () => {
	if (wssInitialized) return;
	const wss = (globalThis as ExtendedGlobal)[globalThisWSS];

	if (wss !== undefined) {
		const listeners = wss.listeners('connection');

		// Remove stale listeners registered before a hot restart
		for (let i = 0; i < listeners.length - 1; i++) {
			wss.removeListener('connection', listeners[i] as () => void);
		}
	}

	wssInitialized = true;
};

export { getWebSocketServer };
