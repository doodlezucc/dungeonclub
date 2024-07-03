import { PrismaClient } from '@prisma/client';
import type { WebSocket } from 'ws';
import { AssetManager } from './asset-manager';
import { Connection } from './connection';
import { getWebSocketServer } from './ws-server';

export const prisma = new PrismaClient();

export class Server {
	readonly assetManager = new AssetManager();
	readonly webSocketManager = new WebSocketManager();
	readonly connections: Connection[] = [];

	async start() {
		this.webSocketManager.start();
	}
}

class WebSocketManager {
	connections: Connection[] = [];

	start() {
		const wss = getWebSocketServer();
		wss.on('connection', (socket) => this.onConnect(socket));
	}

	onConnect(socket: WebSocket) {
		const connection = new Connection(socket);

		socket.on('close', (code) => {
			this.onDisconnect(connection, code);
		});

		this.connections.push(connection);
	}

	private onDisconnect(connection: Connection, code: number) {
		console.log('Closing connection with code', code);
		this.connections = this.connections.filter((conn) => conn !== connection);
	}
}

export const server = new Server();
