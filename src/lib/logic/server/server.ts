import { PrismaClient } from '@prisma/client';
import type { WebSocket } from 'ws';
import { AssetManager } from './asset-manager';
import { SessionManager } from './session';
import { ConnectionSocket } from './socket';
import { getWebSocketServer } from './ws-server/ws-server';

export const prisma = new PrismaClient();

export class Server {
	readonly assetManager = new AssetManager();
	readonly sessionManager = new SessionManager();
	readonly webSocketManager = new WebSocketManager();

	async start() {
		this.webSocketManager.start();
	}
}

class WebSocketManager {
	private connectionSockets: ConnectionSocket[] = [];

	start() {
		const wss = getWebSocketServer();
		wss.removeAllListeners();
		wss.on('connection', (socket) => this.onConnect(socket));
	}

	onConnect(webSocket: WebSocket) {
		const connectionSocket = new ConnectionSocket(webSocket);

		webSocket.on('close', (code) => {
			this.onDisconnect(connectionSocket, code);
		});

		this.connectionSockets.push(connectionSocket);
	}

	private onDisconnect(disconnectedSocket: ConnectionSocket, code: number) {
		console.log('Closing connection with code', code);
		disconnectedSocket.dispose();

		this.connectionSockets = this.connectionSockets.filter(
			(socket) => socket !== disconnectedSocket
		);
	}
}

export const server = new Server();
