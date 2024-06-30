import type { Plugin } from 'vite';
import { createWSSGlobalInstance, onHttpServerUpgrade } from './web-socket-utils.js';

export function webSocketServer(): Plugin {
	return {
		name: 'Web Socket Server',
		configureServer(server) {
			createWSSGlobalInstance();
			server.httpServer?.on('upgrade', onHttpServerUpgrade);
		},
		configurePreviewServer(server) {
			createWSSGlobalInstance();
			server.httpServer?.on('upgrade', onHttpServerUpgrade);
		}
	};
}
