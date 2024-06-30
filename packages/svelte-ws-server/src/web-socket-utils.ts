import type { IncomingMessage } from 'http';
import type { Duplex } from 'stream';
import WebSocketBase, { WebSocket, WebSocketServer } from 'ws';

// Adapted from https://github.com/suhaildawood/SvelteKit-integrated-WebSocket

export const GlobalThisWSS = Symbol.for('sveltekit.wss');

declare class ExtendedWebSocket extends WebSocket {
	socketId: string;
}

export type { ExtendedWebSocket };

export type ExtendedWebSocketServer = WebSocketBase.Server<typeof ExtendedWebSocket>;

export type ExtendedGlobal = typeof globalThis & {
	[GlobalThisWSS]: ExtendedWebSocketServer;
};

export const onHttpServerUpgrade = (req: IncomingMessage, sock: Duplex, head: Buffer) => {
	const url = req.url ?? '';
	if (!url.endsWith('/websocket')) return;

	const wss = (globalThis as ExtendedGlobal)[GlobalThisWSS];

	wss.handleUpgrade(req, sock, head, (ws) => {
		wss.emit('connection', ws, req);
	});
};

export const createWSSGlobalInstance = () => {
	const wss = new WebSocketServer({ noServer: true }) as ExtendedWebSocketServer;

	(globalThis as ExtendedGlobal)[GlobalThisWSS] = wss;

	return wss;
};
