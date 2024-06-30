import { createWSSGlobalInstance, onHttpServerUpgrade } from '$lib/server/web-socket-utils';
import type { Plugin } from 'vite';

export function webSocketServer(): Plugin {
	return {
		name: 'integratedWebsocketServer',
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
