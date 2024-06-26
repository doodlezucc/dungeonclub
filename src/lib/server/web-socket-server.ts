import { PUBLIC_WEBSOCKET_URL } from '$env/static/public';
import { WebSocket, WebSocketServer } from 'ws';

export abstract class IWebSocketManager {
	static instance: IWebSocketManager;
	static _wss: WebSocketServer;

	constructor() {
		IWebSocketManager.instance = this;
		console.log('override instance');
	}

	get wss() {
		return IWebSocketManager._wss;
	}

	abstract onConnect(socket: WebSocket): void;
}

export function setupWebSocketServer() {
	if (IWebSocketManager._wss) return;

	const url = new URL(PUBLIC_WEBSOCKET_URL);
	const port = parseInt(url.port);

	const wss = new WebSocketServer({ port });
	wss.on('connection', (socket) => {
		IWebSocketManager.instance.onConnect(socket);
	});
	IWebSocketManager._wss = wss;
}
